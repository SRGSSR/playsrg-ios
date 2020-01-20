//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "RadioChannelsViewController.h"

#import "ApplicationSettings.h"
#import "HomeViewController.h"
#import "NSBundle+PlaySRG.h"

#import <GoogleCast/GoogleCast.h>
#import <libextobjc/libextobjc.h>

@implementation RadioChannelsViewController

#pragma mark Object lifecycle

- (instancetype)initWithRadioChannels:(NSArray<RadioChannel *> *)radioChannels
{
    NSAssert(radioChannels.count > 0, @"1 radio channel at least expected");
    
    RadioChannel *lastOpenedRadioChannel = ApplicationSettingLastOpenedRadioChannel();
    NSInteger initialPage = 0;
    
    NSMutableArray<UIViewController *> *viewControllers = [NSMutableArray array];
    for (RadioChannel *radioChannel in radioChannels) {
        HomeViewController *viewController = [[HomeViewController alloc] initWithRadioChannel:radioChannel];
        viewController.tabBarItem = [[UITabBarItem alloc] initWithTitle:radioChannel.name image:RadioChannelLogo22Image(radioChannel) tag:0];
        [viewControllers addObject:viewController];
        
        if ([radioChannel isEqual:lastOpenedRadioChannel]) {
            initialPage = [radioChannels indexOfObject:radioChannel];
        }
    }
    
    if (self = [super initWithViewControllers:viewControllers.copy initialPage:initialPage]) {
        self.title = NSLocalizedString(@"Audios", @"Title displayed at the top of the audio view");
    }
    return self;
}

#pragma mark View lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    GCKUICastButton *castButton = [[GCKUICastButton alloc] init];
    castButton.tintColor = self.navigationController.navigationBar.tintColor;
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:castButton];
}

#pragma mark Overrides

- (void)didDisplayViewController:(UIViewController *)viewController animated:(BOOL)animated
{
    [super didDisplayViewController:viewController animated:animated];
    
    HomeViewController *homeViewController = (HomeViewController *)viewController;
    ApplicationSettingSetLastOpenedRadioChannel(homeViewController.radioChannel);
}

#pragma mark SRGAnalyticsViewTracking protocol

- (NSString *)srg_pageViewTitle
{
    return NSLocalizedString(@"Audios", @"[Technical] Title for audio analytics measurements");
}

- (NSArray<NSString *> *)srg_pageViewLevels
{
    return @[ AnalyticsNameForPageType(AnalyticsPageTypeRadio) ];
}

#pragma mark PlayApplicationNavigation protocol

- (BOOL)openApplicationSectionInfo:(ApplicationSectionInfo *)applicationSectionInfo
{
    if (! applicationSectionInfo.radioChannel) {
        return NO;
    }
    
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"%K == %@", @keypath(HomeViewController.new, radioChannel), applicationSectionInfo.radioChannel];
    UIViewController *radioChannelViewController = [self.viewControllers filteredArrayUsingPredicate:predicate].firstObject;
    
    if (! radioChannelViewController || ! [radioChannelViewController conformsToProtocol:@protocol(PlayApplicationNavigation)]) {
        return NO;
    }
    
    // Add the selected view controller to the controller stack.
    // Next `openApplicationSectionInfo:` will be able to push other view controllers in the navigation controller.
    NSInteger pageIndex = [self.viewControllers indexOfObject:radioChannelViewController];
    [self switchToIndex:pageIndex animated:NO];
    
    UIViewController<PlayApplicationNavigation> *navigableRootViewController = (UIViewController<PlayApplicationNavigation> *)radioChannelViewController;
    return [navigableRootViewController openApplicationSectionInfo:applicationSectionInfo];
}

@end
