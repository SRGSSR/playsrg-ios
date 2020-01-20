//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "TabBarController.h"

#import "HomeViewController.h"
#import "LibraryViewController.h"
#import "LivestreamsViewController.h"
#import "MiniPlayerView.h"
#import "NavigationController.h"
#import "PlayApplicationNavigation.h"
#import "PushService.h"
#import "RadioChannelsViewController.h"
#import "SearchViewController.h"
#import "ApplicationSettings.h"
#import "UIColor+PlaySRG.h"

#import <libextobjc/libextobjc.h>
#import <MAKVONotificationCenter/MAKVONotificationCenter.h>
#import <Masonry/Masonry.h>
#import <SRGAppearance/SRGAppearance.h>

static const CGFloat MiniPlayerHeight = 50.f;
static const CGFloat MiniPlayerOffset = 5.f;

@interface TabBarController ()

@property (nonatomic, weak) MiniPlayerView *miniPlayerView;

@end

@implementation TabBarController

#pragma mark Object lifecycle

- (instancetype)init
{
    if (self = [super init]) {
        ApplicationConfiguration *applicationConfiguration = ApplicationConfiguration.sharedApplicationConfiguration;
        
        NSMutableArray<UIViewController *> *viewControllers = NSMutableArray.array;
        NSMutableArray<UITabBarItem *> *tabBarItems = NSMutableArray.array;

        UIViewController *viewController = [[HomeViewController alloc] initWithRadioChannel:nil];
        [viewControllers addObject:viewController];
        [tabBarItems addObject:[[UITabBarItem alloc] initWithTitle:viewController.title image:[UIImage imageNamed:@"videos-25"] tag:TabBarItemIdentifierVideos]];
        
        NSArray<RadioChannel *> *radioChannels = applicationConfiguration.radioChannels;
        if (radioChannels.count > 0) {
            viewController = [[RadioChannelsViewController alloc] initWithRadioChannels:radioChannels];
            [viewControllers addObject:viewController];
            [tabBarItems addObject:[[UITabBarItem alloc] initWithTitle:viewController.title image:[UIImage imageNamed:@"audios-25"] tag:TabBarItemIdentifierAudios]];
        }
        
        NSArray<NSNumber *> *liveHomeSections = ApplicationConfiguration.sharedApplicationConfiguration.liveHomeSections;
        if (liveHomeSections.count > 0) {
            viewController = [[LivestreamsViewController alloc] initWithHomeSections:liveHomeSections];
            [viewControllers addObject:viewController];
            [tabBarItems addObject:[[UITabBarItem alloc] initWithTitle:viewController.title image:[UIImage imageNamed:@"live-25"] tag:TabBarItemIdentifierLivestreams]];
        }
        
        viewController = [[SearchViewController alloc] init];
        [viewControllers addObject:viewController];
        [tabBarItems addObject:[[UITabBarItem alloc] initWithTitle:viewController.title image:[UIImage imageNamed:@"search-25"] tag:TabBarItemIdentifierSearch]];
        
        viewController = [[LibraryViewController alloc] init];
        [viewControllers addObject:viewController];
        [tabBarItems addObject:[[UITabBarItem alloc] initWithTitle:viewController.title image:[UIImage imageNamed:@"library-25"] tag:TabBarItemIdentifierLibrary]];
        
        NSMutableArray<NavigationController *> *navigationControllers = NSMutableArray.array;
        [viewControllers enumerateObjectsUsingBlock:^(UIViewController * _Nonnull viewController, NSUInteger idx, BOOL * _Nonnull stop) {
            NavigationController *navigationController = [[NavigationController alloc] initWithRootViewController:viewController];
            navigationController.delegate = self;
            navigationController.tabBarItem = tabBarItems[idx];
            [navigationControllers addObject:navigationController];
        }];
        self.viewControllers = navigationControllers.copy;
        
        if (@available(iOS 13, *)) {
            self.tabBar.barTintColor = nil;
        }
        else {
            self.tabBar.barTintColor = UIColor.play_blurTintColor;
        }
        
        TabBarItemIdentifier lastOpenTabBarItem = ApplicationSettingLastOpenedTabBarItemIdentifier();
        if (lastOpenTabBarItem) {
            self.selectedIndex = lastOpenTabBarItem;
        }
    }
    return self;
}

#pragma mark View lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    UIColor *foregroundColor = UIColor.whiteColor;
    
    UINavigationBar.appearance.barStyle = UIBarStyleBlack;
    UINavigationBar.appearance.tintColor = foregroundColor;
    UINavigationBar.appearance.titleTextAttributes = @{ NSFontAttributeName : [UIFont srg_mediumFontWithSize:18.f],
                                                        NSForegroundColorAttributeName : foregroundColor };
    
    for (NSNumber *controlState in @[ @(UIControlStateNormal), @(UIControlStateHighlighted), @(UIControlStateDisabled) ]) {
        [UIBarButtonItem.appearance setTitleTextAttributes:@{ NSFontAttributeName : [UIFont srg_regularFontWithSize:16.f],
                                                              NSForegroundColorAttributeName : foregroundColor }
                                                  forState:controlState.integerValue];
    }
    
    UITabBar.appearance.barStyle = UIBarStyleBlack;
    UITabBar.appearance.tintColor = UIColor.whiteColor;
    
    for (NSNumber *controlState in @[ @(UIControlStateNormal), @(UIControlStateHighlighted), @(UIControlStateDisabled) ]) {
        [UITabBarItem.appearance setTitleTextAttributes:@{ NSFontAttributeName : [UIFont srg_regularFontWithSize:12.f],
                                                           NSForegroundColorAttributeName : foregroundColor }
                                               forState:controlState.integerValue];
    }
    
    // The mini player is not available for all BUs
    MiniPlayerView *miniPlayerView = [[MiniPlayerView alloc] initWithFrame:CGRectZero];
    [self.view insertSubview:miniPlayerView belowSubview:self.tabBar];
    
    // iOS 10 bug: Cannot apply a shadow to a blurred view without breaking the blur effect
    // Probably related to radar 27189321.
    // TODO: Remove when iOS 10 is not supported anymore
    if (NSProcessInfo.processInfo.operatingSystemVersion.majorVersion != 10) {
        miniPlayerView.layer.shadowOpacity = 0.9f;
        miniPlayerView.layer.shadowRadius = 5.f;
    }
    
    self.miniPlayerView = miniPlayerView;
    
    @weakify(self)
    [miniPlayerView addObserver:self keyPath:@keypath(miniPlayerView.active) options:0 block:^(MAKVONotification *notification) {
        @strongify(self)
        [self updateLayoutAnimated:YES];
    }];
    
    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(applicationDidBecomeActive:)
                                               name:UIApplicationDidBecomeActiveNotification
                                             object:nil];
    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(didReceiveNotification:)
                                               name:PushServiceDidReceiveNotification
                                             object:nil];
    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(badgeDidChange:)
                                               name:PushServiceBadgeDidChangeNotification
                                             object:nil];
    
    [self updateLayoutAnimated:NO];
}

#pragma mark Rotation

- (BOOL)shouldAutorotate
{
    if (! [super shouldAutorotate]) {
        return NO;
    }
    
    return [self.selectedViewController shouldAutorotate];
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations
{
    UIInterfaceOrientationMask supportedInterfaceOrientations = [super supportedInterfaceOrientations];
    return supportedInterfaceOrientations & [self.selectedViewController supportedInterfaceOrientations];
}

#pragma mark Responsiveness

- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator
{
    [super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];
    
    [coordinator animateAlongsideTransition:^(id<UIViewControllerTransitionCoordinatorContext>  _Nonnull context) {
        [self updateLayoutAnimated:NO];
    } completion:nil];
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection
{
    [super traitCollectionDidChange:previousTraitCollection];
    
    [self updateLayoutAnimated:NO];
}

#pragma mark Status bar

- (BOOL)prefersStatusBarHidden
{
    return [self.selectedViewController prefersStatusBarHidden];
}

- (UIStatusBarStyle)preferredStatusBarStyle
{
    return [self.selectedViewController preferredStatusBarStyle];
}

- (UIStatusBarAnimation)preferredStatusBarUpdateAnimation
{
    return [self.selectedViewController preferredStatusBarUpdateAnimation];
}

#pragma mark Overrides

- (void)setSelectedViewController:(UIViewController *)selectedViewController
{
    [super setSelectedViewController:selectedViewController];
    
    ApplicationSettingSetLastOpenedTabBarItemIdentifier(selectedViewController.tabBarItem.tag);
}


#pragma mark Layout

- (void)updateLayoutAnimated:(BOOL)animated
{
    void (^animations)(void) = ^{
        [self.miniPlayerView mas_remakeConstraints:^(MASConstraintMaker *make) {
            if (@available(iOS 11, *)) {
                make.right.equalTo(self.view.mas_safeAreaLayoutGuideRight).with.offset(-MiniPlayerOffset);
            }
            else {
                make.right.equalTo(self.view).with.offset(-MiniPlayerOffset);
            }
            
            if (UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad) {
                // Use 1/3 of the space, minimum of 500 pixels. If the player cannot fit in 80% of the screen,
                // use all available space.
                CGFloat availableWidth = CGRectGetWidth(self.view.frame) - 2 * MiniPlayerOffset;
                CGFloat width = fmaxf(availableWidth / 3.f, 500.f);
                if (width > 0.8f * availableWidth) {
                    width = availableWidth;
                }
                make.width.equalTo(@(width));
            }
            else {
                if (@available(iOS 11, *)) {
                    make.left.equalTo(self.view.mas_safeAreaLayoutGuideLeft).with.offset(MiniPlayerOffset);
                    make.right.equalTo(self.view.mas_safeAreaLayoutGuideRight).with.offset(-MiniPlayerOffset);
                }
                else {
                    make.left.equalTo(self.view).with.offset(MiniPlayerOffset);
                    make.right.equalTo(self.view).with.offset(-MiniPlayerOffset);
                }
            }
            
            if (self.miniPlayerView.active) {
                make.height.equalTo(@(MiniPlayerHeight));
                make.bottom.equalTo(self.tabBar.mas_top).with.offset(-MiniPlayerOffset);
            }
            else {
                make.height.equalTo(@0);
                make.bottom.equalTo(self.tabBar.mas_top);
            }
        }];
        
        [self play_setNeedsContentInsetsUpdate];
    };
    
    if (animated) {
        [self.view layoutIfNeeded];
        [UIView animateWithDuration:0.2 animations:^{
            animations();
            [self.view layoutIfNeeded];
        }];
    }
    else {
        animations();
    }
}

- (void)updateLibraryTabBarItem
{
    if (@available(iOS 10, *)) {
        UITabBarItem *libraryTabBarItem = [self tabBarItemForIdentifier:TabBarItemIdentifierLibrary];
        NSInteger badgeNumber = UIApplication.sharedApplication.applicationIconBadgeNumber;
        
        if (PushService.sharedService.enabled && libraryTabBarItem && badgeNumber != 0) {
            libraryTabBarItem.badgeValue = (badgeNumber > 99) ? @"99+" : @(badgeNumber).stringValue;
            libraryTabBarItem.badgeColor = UIColor.play_notificationRedColor;
        }
        else {
            libraryTabBarItem.badgeValue = nil;
        }
    }
}

- (UITabBarItem *)tabBarItemForIdentifier:(TabBarItemIdentifier)TabBarItemIdentifier
{
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"%K == %@", @keypath(UITabBarItem.new, tag), @(TabBarItemIdentifier)];
    return [self.tabBar.items filteredArrayUsingPredicate:predicate].firstObject;
}

#pragma mark Push and pop

- (void)pushViewController:(UIViewController *)viewController animated:(BOOL)animated
{
    [self.selectedViewController pushViewController:viewController animated:animated];
}

#pragma mark ContainerContentInsets protocol

- (UIEdgeInsets)play_additionalContentInsets
{
    return UIEdgeInsetsMake(0.f, 0.f, self.miniPlayerView.active ? (MiniPlayerHeight + MiniPlayerOffset) : 0.f, 0.f);
}

#pragma mark PlayApplicationNavigation protocol

- (BOOL)openApplicationSectionInfo:(ApplicationSectionInfo *)applicationSectionInfo
{
    for (UIViewController *viewController in self.viewControllers) {
        if ([viewController conformsToProtocol:@protocol(PlayApplicationNavigation)]) {
            UIViewController<PlayApplicationNavigation> *navigableViewController = (UIViewController<PlayApplicationNavigation> *)viewController;
            if ([navigableViewController openApplicationSectionInfo:applicationSectionInfo]) {
                self.selectedViewController = navigableViewController;
                return YES;
            }
        }
    }
    return NO;
}

#pragma mark Notifications

- (void)applicationDidBecomeActive:(NSNotification *)notification
{
    // Ensure correct notification button availability after:
    //   - Dismissal of the initial system alert (displayed once at most), asking the user to enable push notifications.
    //   - Returning from system settings, where the user might have updated push notification authorizations.
    [self updateLibraryTabBarItem];
}

- (void)didReceiveNotification:(NSNotification *)notification
{
    [self updateLibraryTabBarItem];
}

- (void)badgeDidChange:(NSNotification *)notification
{
    [self updateLibraryTabBarItem];
}

@end
