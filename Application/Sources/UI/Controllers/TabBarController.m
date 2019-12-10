//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "TabBarController.h"

#import "HomeViewController.h"
#import "ProfilViewController.h"
#import "RadiosViewController.h"
#import "SearchViewController.h"

#import <SRGAppearance/SRGAppearance.h>

typedef NS_ENUM(NSInteger, TabBarItem) {
    TabBarItemNone = 0,
    TabBarItemVideos,
    TabBarItemRadios,
    TabBarItemLive,
    TabBarItemSearch,
    TabBarItemProfil
};

@implementation TabBarController

#pragma mark Object lifecycle

- (instancetype)init
{
    self = [super init];
    if (self) {
        ApplicationConfiguration *applicationConfiguration = ApplicationConfiguration.sharedApplicationConfiguration;
        
        NSMutableArray<UIViewController *> *viewControllers = NSMutableArray.array;
        NSMutableArray<UITabBarItem *> *tabBarItems = NSMutableArray.array;

        UIViewController *viewController = [[HomeViewController alloc] initWithRadioChannel:nil];
        [viewControllers addObject:viewController];
        [tabBarItems addObject:[[UITabBarItem alloc] initWithTitle:viewController.title image:[UIImage imageNamed:@"tv-22"] tag:TabBarItemVideos]];
        
        NSArray<RadioChannel *> *radioChannels = applicationConfiguration.radioChannels;
        if (radioChannels.count > 0) {
            viewController = [[RadiosViewController alloc] initWithRadioChannels:radioChannels];
            [viewControllers addObject:viewController];
            [tabBarItems addObject:[[UITabBarItem alloc] initWithTitle:viewController.title image:[UIImage imageNamed:@"radioset-22"] tag:TabBarItemRadios]];
        }
        
        viewController = [[SearchViewController alloc] initWithQuery:nil settings:nil];
        [viewControllers addObject:viewController];
        [tabBarItems addObject:[[UITabBarItem alloc] initWithTitle:viewController.title image:[UIImage imageNamed:@"search-22"] tag:TabBarItemSearch]];
        
        viewController = [[ProfilViewController alloc] init];
        [viewControllers addObject:viewController];
        [tabBarItems addObject:[[UITabBarItem alloc] initWithTitle:viewController.title image:[UIImage imageNamed:@"account-22"] tag:TabBarItemProfil]];
        
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

- (void)viewDidLoad {
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
            tabBarItem = TabBarItemProfil;
            break;
        }
            
        case MenuItemWatchLater: {
            tabBarItem = TabBarItemProfil;
            break;
        }
            
        case MenuItemDownloads: {
            tabBarItem = TabBarItemProfil;
            break;
        }
            
        case MenuItemHistory: {
            tabBarItem = TabBarItemProfil;
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
            tabBarItem = TabBarItemRadios;
            break;
        }
            
        case MenuItemRadioShowAZ: {
            NSAssert(menuItemInfo.radioChannel, @"RadioChannel expected");
            tabBarItem = TabBarItemRadios;
            break;
        }
            
        default: {
            return;
            break;
        }
    }
}

- (void)pushViewController:(UIViewController *)viewController animated:(BOOL)animated
{
    [self.selectedViewController pushViewController:viewController animated:animated];
}

- (void)displayAccountHeaderAnimated:(BOOL)animated
{
    self.selectedIndex = self.viewControllers.count - 1;
    UINavigationController *navigationController = self.selectedViewController;
    [navigationController popToRootViewControllerAnimated:animated];
    
    ProfilViewController *profilViewController = navigationController.viewControllers.firstObject;
    [profilViewController scrollToTopAnimated:animated];
}

@end
