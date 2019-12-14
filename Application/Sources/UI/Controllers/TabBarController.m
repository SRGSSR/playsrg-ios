//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "TabBarController.h"

#import "HomeViewController.h"
#import "LivesViewController.h"
#import "MiniPlayerView.h"
#import "ProfileViewController.h"
#import "AudiosViewController.h"
#import "SearchViewController.h"

#import <libextobjc/libextobjc.h>
#import <MAKVONotificationCenter/MAKVONotificationCenter.h>
#import <Masonry/Masonry.h>
#import <SRGAppearance/SRGAppearance.h>

typedef NS_ENUM(NSInteger, TabBarItem) {
    TabBarItemNone = 0,
    TabBarItemVideos,
    TabBarItemAudios,
    TabBarItemLives,
    TabBarItemSearch,
    TabBarItemProfile
};

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
        [tabBarItems addObject:[[UITabBarItem alloc] initWithTitle:viewController.title image:[UIImage imageNamed:@"videos-25"] tag:TabBarItemVideos]];
        
        NSArray<RadioChannel *> *radioChannels = applicationConfiguration.radioChannels;
        if (radioChannels.count > 0) {
            viewController = [[AudiosViewController alloc] initWithRadioChannels:radioChannels];
            [viewControllers addObject:viewController];
            [tabBarItems addObject:[[UITabBarItem alloc] initWithTitle:viewController.title image:[UIImage imageNamed:@"audio-25"] tag:TabBarItemAudios]];
        }
        
        NSArray<NSNumber *> *liveSections = ApplicationConfiguration.sharedApplicationConfiguration.liveSections;
        if (liveSections.count > 0) {
            viewController = [[LivesViewController alloc] initWithSections:liveSections];
            [viewControllers addObject:viewController];
            [tabBarItems addObject:[[UITabBarItem alloc] initWithTitle:viewController.title image:[UIImage imageNamed:@"lives-25"] tag:TabBarItemLives]];
        }
        
        viewController = [[SearchViewController alloc] initWithQuery:nil settings:nil];
        [viewControllers addObject:viewController];
        [tabBarItems addObject:[[UITabBarItem alloc] initWithTitle:viewController.title image:[UIImage imageNamed:@"search-25"] tag:TabBarItemSearch]];
        
        viewController = [[ProfileViewController alloc] init];
        [viewControllers addObject:viewController];
        [tabBarItems addObject:[[UITabBarItem alloc] initWithTitle:viewController.title image:[UIImage imageNamed:@"profile-25"] tag:TabBarItemProfile]];
        
        NSMutableArray<UINavigationController *> *navigationControllers = NSMutableArray.array;
        [viewControllers enumerateObjectsUsingBlock:^(UIViewController * _Nonnull viewController, NSUInteger idx, BOOL * _Nonnull stop) {
            UINavigationController *navigationController = [[UINavigationController alloc] initWithRootViewController:viewController];
            navigationController.delegate = self;
            navigationController.tabBarItem = tabBarItems[idx];
            [navigationControllers addObject:navigationController];
        }];
        
        self.viewControllers = navigationControllers.copy;
    }
    return self;
}

#pragma mark View lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    UIColor *foregroundColor = UIColor.whiteColor;
    
    UINavigationBar.appearance.tintColor = foregroundColor;
    UINavigationBar.appearance.titleTextAttributes = @{ NSFontAttributeName : [UIFont srg_mediumFontWithSize:18.f],
                                                        NSForegroundColorAttributeName : foregroundColor };
    
    for (NSNumber *controlState in @[ @(UIControlStateNormal), @(UIControlStateHighlighted), @(UIControlStateDisabled) ]) {
        [UIBarButtonItem.appearance setTitleTextAttributes:@{ NSFontAttributeName : [UIFont srg_regularFontWithSize:16.f],
                                                              NSForegroundColorAttributeName : foregroundColor }
                                                  forState:controlState.integerValue];
    }
    
    UITabBar.appearance.tintColor = UIColor.whiteColor;
    
    for (NSNumber *controlState in @[ @(UIControlStateNormal), @(UIControlStateHighlighted), @(UIControlStateDisabled) ]) {
        [UITabBarItem.appearance setTitleTextAttributes:@{ NSFontAttributeName : [UIFont srg_regularFontWithSize:12.f],
                                                           NSForegroundColorAttributeName : foregroundColor }
                                               forState:controlState.integerValue];
    }
    
    // The mini player is not available for all BUs
    MiniPlayerView *miniPlayerView = [[MiniPlayerView alloc] initWithFrame:CGRectZero];
    [self.view addSubview:miniPlayerView];
    
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
    
    [self updateLayoutAnimated:NO];
}

#pragma mark Changing content

- (void)openMenuItemInfo:(MenuItemInfo *)menuItemInfo
{
    TabBarItem tabBarItem = TabBarItemNone;
    switch (menuItemInfo.menuItem) {
        case MenuItemSearch: {
            tabBarItem = TabBarItemSearch;
            break;
        }
            
        case MenuItemFavorites: {
            tabBarItem = TabBarItemProfile;
            break;
        }
            
        case MenuItemWatchLater: {
            tabBarItem = TabBarItemProfile;
            break;
        }
            
        case MenuItemDownloads: {
            tabBarItem = TabBarItemProfile;
            break;
        }
            
        case MenuItemHistory: {
            tabBarItem = TabBarItemProfile;
            break;
        }
            
        case MenuItemTVOverview: {
            tabBarItem = TabBarItemVideos;
            break;
        }
            
        case MenuItemTVByDate: {
            tabBarItem = TabBarItemVideos;
            break;
        }
            
        case MenuItemTVShowAZ: {
            tabBarItem = TabBarItemVideos;
            break;
        }
            
        case MenuItemRadio: {
            NSAssert(menuItemInfo.radioChannel, @"RadioChannel expected");
            tabBarItem = TabBarItemAudios;
            break;
        }
            
        case MenuItemRadioShowAZ: {
            NSAssert(menuItemInfo.radioChannel, @"RadioChannel expected");
            tabBarItem = TabBarItemAudios;
            break;
        }
            
        default: {
            return;
            break;
        }
    }
}

#pragma mark Layout

- (void)updateLayoutAnimated:(BOOL)animated
{
    void (^animations)(void) = ^{
        if (self.miniPlayerView.active) {
            [self.miniPlayerView mas_remakeConstraints:^(MASConstraintMaker *make) {
                make.left.equalTo(self.view).with.offset(MiniPlayerOffset);
                make.right.equalTo(self.view).with.offset(-MiniPlayerOffset);
                
                if (@available(iOS 11, *)) {
                    make.bottom.equalTo(self.tabBar.mas_safeAreaLayoutGuideTop).with.offset(-MiniPlayerOffset);
                    make.top.equalTo(self.tabBar.mas_safeAreaLayoutGuideTop).with.offset(-MiniPlayerOffset - MiniPlayerHeight);
                }
                else {
                    make.bottom.equalTo(self.tabBar.mas_top).with.offset(-MiniPlayerOffset);
                    make.height.equalTo(@(MiniPlayerHeight));
                }
            }];
        }
        else {
            [self.miniPlayerView mas_remakeConstraints:^(MASConstraintMaker *make) {
                make.left.equalTo(self.view).with.offset(MiniPlayerOffset);
                make.right.equalTo(self.view).with.offset(-MiniPlayerOffset);
                if (@available(iOS 11, *)) {
                    make.bottom.equalTo(self.tabBar.mas_safeAreaLayoutGuideTop).with.offset(-MiniPlayerOffset);
                }
                else {
                    make.bottom.equalTo(self.tabBar.mas_top).with.offset(-MiniPlayerOffset);
                }
                make.height.equalTo(@0);
            }];
        }
        
        [self.navigationController.viewControllers enumerateObjectsUsingBlock:^(__kindof UIViewController * _Nonnull viewController, NSUInteger idx, BOOL * _Nonnull stop) {
            [viewController play_setNeedsContentInsetsUpdate];
        }];
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

- (void)displayAccountHeaderAnimated:(BOOL)animated
{
    self.selectedIndex = self.viewControllers.count - 1;
    UINavigationController *navigationController = self.selectedViewController;
    [navigationController popToRootViewControllerAnimated:animated];
    
    ProfileViewController *profileViewController = navigationController.viewControllers.firstObject;
    [profileViewController scrollToTopAnimated:animated];
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

@end
