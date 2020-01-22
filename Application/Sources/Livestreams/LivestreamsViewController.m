//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "LivestreamsViewController.h"

#import "ApplicationConfiguration.h"
#import "ApplicationSettings.h"
#import "GoogleCastBarButtonItem.h"
#import "HomeLivestreamsViewController.h"

#import <libextobjc/libextobjc.h>

@implementation LivestreamsViewController

#pragma mark Object lifecycle

- (instancetype)initWithHomeSections:(NSArray<NSNumber *> *)homeSections
{
    NSAssert(homeSections.count > 0, @"1 live section at least expected");
    
    NSMutableArray<UIViewController *> *viewControllers = [NSMutableArray array];
    for (NSNumber *homeSectionNumber in homeSections) {
        HomeSection homeSection = homeSectionNumber.integerValue;
        HomeSectionInfo *homeSectionInfo = [[HomeSectionInfo alloc] initWithHomeSection:homeSection];
        HomeLivestreamsViewController *viewController = [[HomeLivestreamsViewController alloc] initWithHomeSectionInfo:homeSectionInfo];
        [viewControllers addObject:viewController];
    }
    
    NSUInteger initialPage = [homeSections indexOfObject:@(ApplicationSettingLastOpenedLivestreamHomeSection())];
    if (self = [super initWithViewControllers:viewControllers.copy initialPage:initialPage]) {
        self.title = NSLocalizedString(@"Live", @"Title displayed at the top of the livestreams view");
    }
    return self;
}

#pragma mark View lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    UINavigationBar *navigationBar = self.navigationController.navigationBar;
    if (navigationBar) {
        self.navigationItem.rightBarButtonItem = [[GoogleCastBarButtonItem alloc] initForNavigationBar:navigationBar];
    }
}

#pragma mark Overrides

- (void)didDisplayViewController:(UIViewController *)viewController animated:(BOOL)animated
{
    [super didDisplayViewController:viewController animated:animated];
    
    HomeLivestreamsViewController *homeViewController = (HomeLivestreamsViewController *)viewController;
    ApplicationSettingSetLastOpenedLivestreamHomeSection(homeViewController.homeSectionInfo.homeSection);
}

#pragma mark SRGAnalyticsViewTracking protocol

- (NSString *)srg_pageViewTitle
{
    return NSLocalizedString(@"Live", @"[Technical] Title for livestreams analytics measurements");
}

- (NSArray<NSString *> *)srg_pageViewLevels
{
    return @[ AnalyticsNameForPageType(AnalyticsPageTypeRadio) ];
}

#pragma mark PlayApplicationNavigation protocol

- (BOOL)openApplicationSectionInfo:(ApplicationSectionInfo *)applicationSectionInfo
{
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"%K == %@", @keypath(HomeLivestreamsViewController.new, homeSectionInfo.homeSection), @(HomeSectionForApplicationSection(applicationSectionInfo.applicationSection))];
    UIViewController *viewController = [self.viewControllers filteredArrayUsingPredicate:predicate].firstObject;
    
    if (! viewController || ! [viewController conformsToProtocol:@protocol(PlayApplicationNavigation)]) {
        return NO;
    }
    
    // Add the selected view controller to the controller stack.
    // Next `openApplicationSectionInfo:` will be able to push other view controllers in the navigation controller.
    NSInteger pageIndex = [self.viewControllers indexOfObject:viewController];
    [self switchToIndex:pageIndex animated:NO];
    
    UIViewController<PlayApplicationNavigation> *navigableRootViewController = (UIViewController<PlayApplicationNavigation> *)viewController;
    return [navigableRootViewController openApplicationSectionInfo:applicationSectionInfo];
}

@end
