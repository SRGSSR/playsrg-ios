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
        viewController.play_pageItem = [[PageItem alloc] initWithTitle:radioChannel.name image:RadioChannelLogo22Image(radioChannel)];
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

#pragma mark Override

- (BOOL)switchToIndex:(NSInteger)index animated:(BOOL)animated
{
    BOOL switched = [super switchToIndex:index animated:animated];
    if (switched) {
        HomeViewController *selectedHomeViewController = (HomeViewController *)self.viewControllers[index];
        ApplicationSettingSetLastOpenedRadioChannel(selectedHomeViewController.radioChannel);
    }
    return switched;
}

- (UIViewController *)pageViewController:(UIPageViewController *)pageViewController viewControllerBeforeViewController:(UIViewController *)viewController
{
    HomeViewController *currentHomeViewController = (HomeViewController *)viewController;
    ApplicationSettingSetLastOpenedRadioChannel(currentHomeViewController.radioChannel);
    
    return [super pageViewController:pageViewController viewControllerBeforeViewController:viewController];
}

- (UIViewController *)pageViewController:(UIPageViewController *)pageViewController viewControllerAfterViewController:(UIViewController *)viewController
{
    HomeViewController *currentHomeViewController = (HomeViewController *)viewController;
    ApplicationSettingSetLastOpenedRadioChannel(currentHomeViewController.radioChannel);
    
    return [super pageViewController:pageViewController viewControllerAfterViewController:viewController];
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
