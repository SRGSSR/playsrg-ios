//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "LivestreamsViewController.h"

#import "ApplicationConfiguration.h"
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
        HomeLivestreamsViewController *viewController = [[HomeLivestreamsViewController alloc] initWithHomeSectionInfo:[[HomeSectionInfo alloc] initWithHomeSection:homeSection]];
        [viewControllers addObject:viewController];
    }
    
    if (self = [super initWithViewControllers:viewControllers.copy]) {
        self.title = NSLocalizedString(@"Live", @"Title displayed at the top of the livestreams view");
    }
    return self;
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
