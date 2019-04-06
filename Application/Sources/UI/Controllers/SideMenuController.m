//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "SideMenuController.h"

#import "ApplicationSettings.h"
#import "CalendarViewController.h"
#import "DownloadsViewController.h"
#import "FavoritesViewController.h"
#import "HistoryViewController.h"
#import "HomeViewController.h"
#import "MainNavigationController.h"
#import "NSBundle+PlaySRG.h"
#import "PageViewController.h"
#import "RadioShowsViewController.h"
#import "SearchViewController.h"
#import "SettingsViewController.h"
#import "ShowsViewController.h"
#import "SubscriptionsViewController.h"
#import "UIDevice+PlaySRG.h"
#import "WatchLaterViewController.h"
#import "WebViewController.h"

#import <ComScore/ComScore.h>
#import <libextobjc/libextobjc.h>
#import <Masonry/Masonry.h>

static const CGFloat SideMenuOffset = -50.f;

@interface SideMenuController ()

@property (nonatomic) MainNavigationController *mainNavigationController;
@property (nonatomic) MenuViewController *menuViewController;

@property (nonatomic, weak) UIView *centerView;
@property (nonatomic, weak) UIView *menuView;

@property (nonatomic, weak) UIView *closeInteractionView;

@property (nonatomic, readonly, getter=isMenuOpen) BOOL menuOpen;
@property (nonatomic) float progress;

@property (nonatomic, weak) CADisplayLink *displayLink;

@end

@implementation SideMenuController

@synthesize selectedMenuItemInfo = _selectedMenuItemInfo;

#pragma mark Getters and setters

- (void)setMainNavigationController:(MainNavigationController *)mainNavigationController
{
    NSAssert(self.centerView, @"The center view must be available");
    
    if (_mainNavigationController) {
        [_mainNavigationController.view removeFromSuperview];
        [_mainNavigationController removeFromParentViewController];
    }
    
    _mainNavigationController = mainNavigationController;
    
    if (mainNavigationController) {
        [self.centerView addSubview:mainNavigationController.view];
        [mainNavigationController.view mas_makeConstraints:^(MASConstraintMaker *make) {
            make.edges.equalTo(self.centerView);
        }];
        
        // The containment relationship must be established after the child view has been added so that layout guides
        // are correct (pre-iOS 11).
        [self addChildViewController:mainNavigationController];
        [mainNavigationController didMoveToParentViewController:self];
    }
}

- (void)setMenuViewController:(MenuViewController *)menuViewController
{
    NSAssert(self.menuView, @"The menu view must be available");
    
    if (_menuViewController) {
        [_menuViewController.view removeFromSuperview];
        [_menuViewController removeFromParentViewController];
    }
    
    _menuViewController = menuViewController;
    
    if (menuViewController) {
        [self.menuView addSubview:menuViewController.view];
        [menuViewController.view mas_makeConstraints:^(MASConstraintMaker *make) {
            make.edges.equalTo(self.menuView);
        }];
        
        // The containment relationship must be established after the child view has been added so that layout guides
        // are correct (pre-iOS 11).
        [self addChildViewController:menuViewController];
        [menuViewController didMoveToParentViewController:self];
    }
}

- (void)setSelectedMenuItemInfo:(MenuItemInfo *)selectedMenuItemInfo
{
    [self setSelectedMenuItemInfo:selectedMenuItemInfo animated:NO];
}

- (MenuItemInfo *)selectedMenuItemInfo
{
    return _selectedMenuItemInfo;
}

- (UIViewController *)masterViewController
{
    return self.menuOpen ? self.menuViewController : self.mainNavigationController;
}

- (void)setDisplayLink:(CADisplayLink *)displayLink
{
    if (_displayLink) {
        [_displayLink invalidate];
    }
    
    _displayLink = displayLink;
}

// The menu is considered open even if slightly open
- (BOOL)isMenuOpen
{
    return CGRectGetMinX(self.centerView.frame) > 0.f;
}

- (CGFloat)sideMenuWidth
{
    return fmin(0.8f * CGRectGetWidth(self.view.frame), 320.f);
}

#pragma mark View lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    // Menu view. Fixed width.
    UIView *menuView = [[UIView alloc] initWithFrame:self.view.bounds];
    [self.view addSubview:menuView];
    [menuView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.view).offset(SideMenuOffset);
        make.top.equalTo(self.view);
        make.bottom.equalTo(self.view);
        make.width.equalTo(@([self sideMenuWidth]));
    }];
    self.menuView = menuView;
    
    // Center view.
    UIView *centerView = [[UIView alloc] initWithFrame:self.view.bounds];
    [self.view addSubview:centerView];
    [centerView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.view);
        make.top.equalTo(self.view);
        make.bottom.equalTo(self.view);
        make.width.equalTo(self.view);
    }];
    self.centerView = centerView;
    
    // Transparent view to catch taps on the center view when the menu is open
    UIView *closeInteractionView = [[UIView alloc] initWithFrame:self.view.bounds];
    closeInteractionView.backgroundColor = UIColor.clearColor;
    closeInteractionView.hidden = YES;
    [self.view addSubview:closeInteractionView];
    [closeInteractionView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.edges.equalTo(self.centerView);
    }];
    self.closeInteractionView = closeInteractionView;
    
    UITapGestureRecognizer *tapGestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(closeMenu:)];
    [closeInteractionView addGestureRecognizer:tapGestureRecognizer];
    
    UIPanGestureRecognizer *panGestureRecognizer = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(dragInteractionView:)];
    [panGestureRecognizer requireGestureRecognizerToFail:tapGestureRecognizer];
    [closeInteractionView addGestureRecognizer:panGestureRecognizer];
    
    UIScreenEdgePanGestureRecognizer *screenEdgePanGestureRecognizer = [[UIScreenEdgePanGestureRecognizer alloc] initWithTarget:self action:@selector(panFromLeftEdge:)];
    screenEdgePanGestureRecognizer.edges = UIRectEdgeLeft;
    screenEdgePanGestureRecognizer.delegate = self;
    [self.view addGestureRecognizer:screenEdgePanGestureRecognizer];
    
    self.menuViewController = [[MenuViewController alloc] init];
    self.menuViewController.delegate = self;
    
    // Start with the last open homepage, radio page or the TV overview
    self.selectedMenuItemInfo = ApplicationSettingLastOpenHomepageMenuItemInfo();
    
    [self updateAppearanceWithProgress:0.f];
}

#pragma mark Rotation

- (BOOL)shouldAutorotate
{
    if (! [super shouldAutorotate]) {
        return NO;
    }
    
    return [self.mainNavigationController shouldAutorotate] && [self.menuViewController shouldAutorotate];
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations
{
    UIInterfaceOrientationMask supportedInterfaceOrientations = [super supportedInterfaceOrientations];
    return supportedInterfaceOrientations
        & [self.mainNavigationController supportedInterfaceOrientations]
        & [self.menuViewController supportedInterfaceOrientations];
}

#pragma mark Responsiveness

- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator
{
    [super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];
    
    [coordinator animateAlongsideTransition:^(id<UIViewControllerTransitionCoordinatorContext> _Nonnull context) {
        [self updateAppearanceWithProgress:self.progress];
    } completion:nil];
}

#pragma mark Status bar

// The master controller is the menu when slightly open. Since the menu draws user attention in such cases, it
// must namely have a perfectly matching status bar.

- (BOOL)prefersStatusBarHidden
{
    return [self.masterViewController prefersStatusBarHidden];
}

- (UIStatusBarStyle)preferredStatusBarStyle
{
    return [self.masterViewController preferredStatusBarStyle];
}

- (UIStatusBarAnimation)preferredStatusBarUpdateAnimation
{
    return [self.masterViewController preferredStatusBarUpdateAnimation];
}

#pragma mark Accessibility

- (BOOL)accessibilityPerformEscape
{
    if (self.mainNavigationController.viewControllers.count == 1) {
        [self setMenuOpen:! self.menuOpen animated:YES withCompletion:nil];
    }
    return YES;
}

#pragma mark Menu animation

- (void)setMenuOpen:(BOOL)open animated:(BOOL)animated withCompletion:(void (^)(BOOL finished))completion
{
    self.closeInteractionView.hidden = ! open;
    
    // Move accessibility focus to the appropriate container view
    self.menuView.accessibilityElementsHidden = ! open;
    self.centerView.accessibilityElementsHidden = open;
    
    // Force an accessibility focus update
    UIAccessibilityPostNotification(UIAccessibilityScreenChangedNotification, open ? self.menuView : self.centerView);
    
    NSString *announcement = open ? PlaySRGAccessibilityLocalizedString(@"Menu open", @"Announcement made when the left menu is opened") : PlaySRGAccessibilityLocalizedString(@"Menu closed", @"Announcement made when the left menu is closed");
    UIAccessibilityPostNotification(UIAccessibilityAnnouncementNotification, announcement);
    
    // Dismiss the keyboard if any view was the responder
    [[self.centerView firstResponderView] resignFirstResponder];
    
    CGFloat finalProgress = open ? 1.f : 0.f;
    
    void (^animations)(void) = ^{
        [self updateAppearanceWithProgress:finalProgress];
    };
    
    if (animated) {
        CADisplayLink *displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(updateStatusBar:)];
        [displayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
        self.displayLink = displayLink;
        
        [self.view layoutIfNeeded];
        [UIView animateWithDuration:0.2 delay:0. options:UIViewAnimationOptionAllowUserInteraction animations:^{
            animations();
            [self.view layoutIfNeeded];
        } completion:^(BOOL finished) {
            // Force to 1 on completion. This avoids sometimes incorrect status bar appearance on iOS 9
            // TODO: Remove when iOS 10 is the minimum deployment target
            if (finished) {
                [self updateAppearanceWithProgress:finalProgress];
                
                if (open) {
                    [self.menuViewController focus];
                }
            }
            self.displayLink = displayLink;
            completion ? completion(finished) : nil;
        }];
    }
    else {
        animations();
        [self setNeedsStatusBarAppearanceUpdate];
        completion ? completion(YES) : nil;
    }
}

- (void)toggleMenuAnimated:(BOOL)animated
{
    [self setMenuOpen:! self.menuOpen animated:animated withCompletion:nil];
}

- (void)updateAppearanceWithProgress:(float)progress
{
    self.progress = fmaxf(fminf(progress, 1.f), 0.f);
    
    [self.centerView mas_updateConstraints:^(MASConstraintMaker *make) {
        CGFloat offset = [self sideMenuWidth] * self.progress;
        make.left.equalTo(self.view).offset(offset);
    }];
    [self.menuView mas_updateConstraints:^(MASConstraintMaker *make) {
        CGFloat offset = (1.f - self.progress) * SideMenuOffset;
        make.left.equalTo(self.view).offset(offset);
    }];
    self.menuView.alpha = progress;
    [self setNeedsStatusBarAppearanceUpdate];
}

- (void)displayMenuHeaderAnimated:(BOOL)animated
{
    if (! self.menuOpen) {
        @weakify(self)
        [self setMenuOpen:YES animated:animated withCompletion:^(BOOL finished) {
            @strongify(self)
            [self.menuViewController scrollToTopAnimated:animated];
        }];
    }
    else {
        [self.menuViewController scrollToTopAnimated:animated];
    }
}

#pragma mark Changing content

- (void)pushViewController:(UIViewController *)viewController animated:(BOOL)animated
{
    [self.mainNavigationController pushViewController:viewController animated:animated];
}

- (void)setSelectedMenuItemInfo:(MenuItemInfo *)selectedMenuItemInfo animated:(BOOL)animated
{
    if (! [self.selectedMenuItemInfo isEqual:selectedMenuItemInfo]) {
        _selectedMenuItemInfo = selectedMenuItemInfo;
        
        self.menuViewController.selectedMenuItemInfo = selectedMenuItemInfo;
        
        ApplicationConfiguration *applicationConfiguration = ApplicationConfiguration.sharedApplicationConfiguration;
        
        UIViewController *viewController = nil;
        switch (selectedMenuItemInfo.menuItem) {
            case MenuItemSearch: {
                viewController = [[SearchViewController alloc] init];
                break;
            }
                
            case MenuItemFavorites: {
                viewController = [[FavoritesViewController alloc] init];
                break;
            }
                
            case MenuItemSubscriptions: {
                viewController = [[SubscriptionsViewController alloc] init];
                break;
            }
                
            case MenuItemWatchLater: {
                viewController = [[WatchLaterViewController alloc] init];
                break;
            }
                
            case MenuItemDownloads: {
                viewController = [[DownloadsViewController alloc] init];
                break;
            }
                
            case MenuItemHistory: {
                viewController = [[HistoryViewController alloc] init];
                break;
            }
                
            case MenuItemTVOverview: {
                viewController = [[HomeViewController alloc] initWithRadioChannel:nil];
                break;
            }
                
            case MenuItemTVByDate: {
                viewController = [[CalendarViewController alloc] init];
                break;
            }
                
            case MenuItemTVShowAZ: {
                viewController = [[ShowsViewController alloc] init];
                break;
            }
                
            case MenuItemFeedback: {
                NSAssert(applicationConfiguration.feedbackURL, @"Feedback URL expected");
                
                NSMutableArray *queryItems = [NSMutableArray array];
                [queryItems addObject:[NSURLQueryItem queryItemWithName:@"platform" value:@"iOS"]];
                
                NSString *appVersion = [NSBundle.mainBundle objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
                [queryItems addObject:[NSURLQueryItem queryItemWithName:@"version" value:appVersion]];
                
                BOOL isPad = UIDevice.play_deviceType == DeviceTypePad;
                [queryItems addObject:[NSURLQueryItem queryItemWithName:@"type" value:isPad ? @"tablet" : @"phone"]];
                [queryItems addObject:[NSURLQueryItem queryItemWithName:@"model" value:UIDevice.currentDevice.model]];
                
                NSString *visitorID = [CSComScore visitorID];
                if (visitorID) {
                    [queryItems addObject:[NSURLQueryItem queryItemWithName:@"cid" value:visitorID]];
                }
                
                NSURL *feedbackURL = applicationConfiguration.feedbackURL;
                NSURLComponents *URLComponents = [NSURLComponents componentsWithURL:feedbackURL resolvingAgainstBaseURL:NO];
                URLComponents.queryItems = [queryItems copy];
                
                NSURLRequest *request = [NSURLRequest requestWithURL:URLComponents.URL];
                viewController = [[WebViewController alloc] initWithRequest:request customizationBlock:^(WKWebView *webView) {
                    webView.scrollView.scrollEnabled = NO;
                } decisionHandler:nil analyticsPageType:AnalyticsPageTypeSystem];
                viewController.title = NSLocalizedString(@"Your feedback", @"Title displayed at the top of the feedback view");
                break;
            }
                
            case MenuItemSettings: {
                viewController = [[SettingsViewController alloc] init];
                break;
            }
                
            case MenuItemHelp: {
                NSAssert(applicationConfiguration.impressumURL, @"Impressum URL expected");
                NSURLRequest *request = [NSURLRequest requestWithURL:applicationConfiguration.impressumURL];
                WebViewController *impressumWebViewController = [[WebViewController alloc] initWithRequest:request customizationBlock:^(WKWebView * _Nonnull webView) {
                    webView.scrollView.indicatorStyle = UIScrollViewIndicatorStyleWhite;
                } decisionHandler:nil analyticsPageType:AnalyticsPageTypeSystem];
                impressumWebViewController.title = NSLocalizedString(@"Help and copyright", @"Title displayed at the top of the help and copyright view");
                impressumWebViewController.tracked = NO;            // The website we display is already tracked.
                viewController = impressumWebViewController;
                break;
            }
                
            case MenuItemRadio: {
                NSAssert(selectedMenuItemInfo.radioChannel, @"RadioChannel expected");
                viewController = [[HomeViewController alloc] initWithRadioChannel:selectedMenuItemInfo.radioChannel];
                break;
            }
                
            case MenuItemRadioShowAZ: {
                NSArray<RadioChannel *> *radioChannels = applicationConfiguration.radioChannels;
                NSAssert(radioChannels.count > 0, @"Radio channels expected");
                if (radioChannels.count > 1) {
                    viewController = [[RadioShowsViewController alloc] initWithRadioChannels:radioChannels];
                }
                else {
                    viewController = [[ShowsViewController alloc] initWithRadioChannel:radioChannels.firstObject];
                }
                break;
            }
                
            default: {
                return;
                break;
            }
        }
        
        MainNavigationController *mainNavigationController = [[MainNavigationController alloc] initWithRootViewController:viewController
                                                                                                             radioChannel:selectedMenuItemInfo.radioChannel];
        mainNavigationController.delegate = self;
        self.mainNavigationController = mainNavigationController;
        
        ApplicationSettingSetLastOpenHomepageMenuItemInfo(selectedMenuItemInfo);
    }
    else {
        [self.mainNavigationController popToRootViewControllerAnimated:NO];
    }
    
    if (self.menuOpen) {
        [self setMenuOpen:NO animated:animated withCompletion:nil];
    }
}

#pragma mark MenuViewControllerDelegate protocol

- (void)menuViewController:(MenuViewController *)menuViewController didSelectMenuItemInfo:(MenuItemInfo *)menuItemInfo
{
    [self setSelectedMenuItemInfo:menuItemInfo animated:YES];
}

#pragma mark UIGestureRecognizerDelegate protocol

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch
{
    return ! self.menuOpen;
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRequireFailureOfGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer
{
    // Ensure other screen edge pan gesture recognizers take precedence over the menu recognizer
    return [otherGestureRecognizer isKindOfClass:UIScreenEdgePanGestureRecognizer.class];
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldBeRequiredToFailByGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer
{
    return YES;
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer
{
    return YES;
}

#pragma mark MainNavigationControllerDelegate protocol

- (void)mainNavigationController:(MainNavigationController *)navigationController willShowViewController:(UIViewController *)viewController animated:(BOOL)animated
{
    UINavigationItem *navigationItem = viewController.navigationItem;
    
    // Only display menu button on the root view controller
    if (viewController == navigationController.viewControllers.firstObject) {
        UIBarButtonItem *barButtonItem = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"menu-22"]
                                                                          style:UIBarButtonItemStylePlain
                                                                         target:self
                                                                         action:@selector(toggleMenu:)];
        barButtonItem.accessibilityLabel = PlaySRGAccessibilityLocalizedString(@"Menu", @"Menu button label");
        navigationItem.leftBarButtonItem = barButtonItem;
    }
    else {
        navigationItem.leftBarButtonItem = nil;
    }
}

#pragma mark Actions

- (void)toggleMenu:(id)sender
{
    [self toggleMenuAnimated:YES];
}

#pragma mark Gesture recognizers

- (void)closeMenu:(UIGestureRecognizer *)gestureRecognizer
{
    [self setMenuOpen:NO animated:YES withCompletion:nil];
}

- (void)panFromLeftEdge:(UIScreenEdgePanGestureRecognizer *)panGestureRecognizer
{
    CGFloat progress = [panGestureRecognizer translationInView:self.view].x / [self sideMenuWidth];
    
    switch (panGestureRecognizer.state) {
        case UIGestureRecognizerStateBegan : {
            // Dismiss the keyboard if any view was the responder
            [[self.centerView firstResponderView] resignFirstResponder];
            break;
        }
            
        case UIGestureRecognizerStateChanged: {
            [self updateAppearanceWithProgress:progress];
            break;
        }
            
        case UIGestureRecognizerStateFailed:
        case UIGestureRecognizerStateCancelled:
        case UIGestureRecognizerStateEnded: {
            CGFloat velocity = [panGestureRecognizer velocityInView:self.view].x;
            [self setMenuOpen:(velocity > 0.f || (velocity == 0.f && progress > 0.5f)) animated:YES withCompletion:nil];
            break;
        }
            
        default: {
            break;
        }
    }
}

- (void)dragInteractionView:(UIPanGestureRecognizer *)panGestureRecognizer
{
    CGFloat progress = 1.f + [panGestureRecognizer translationInView:self.view].x / [self sideMenuWidth];
    
    switch (panGestureRecognizer.state) {
        case UIGestureRecognizerStateChanged: {
            [self updateAppearanceWithProgress:progress];
            break;
        }
            
        case UIGestureRecognizerStateFailed:
        case UIGestureRecognizerStateCancelled:
        case UIGestureRecognizerStateEnded: {
            CGFloat velocity = [panGestureRecognizer velocityInView:self.view].x;
            [self setMenuOpen:(velocity > 0.f || (velocity == 0.f && progress > 0.5f)) animated:YES withCompletion:nil];
            break;
        }
            
        default: {
            break;
        }
    }
}

#pragma mark Display links

- (void)updateStatusBar:(CADisplayLink *)displayLink
{
    [self setNeedsStatusBarAppearanceUpdate];
}

@end
