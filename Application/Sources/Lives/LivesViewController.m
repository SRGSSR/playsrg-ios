//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "LivesViewController.h"

#import "ApplicationConfiguration.h"
#import "HomeMediasViewController.h"

@implementation LivesViewController

#pragma mark Object lifecycle

- (instancetype)initWithHomeSections:(NSArray<NSNumber *> *)homeSections
{
    NSAssert(homeSections.count > 0, @"1 live section at least expected");
    
    NSMutableArray<UIViewController *> *viewControllers = [NSMutableArray array];
    for (NSNumber *homeSectionNumber in homeSections) {
        HomeSection homeSection = homeSectionNumber.integerValue;
        HomeMediasViewController *viewController = [[HomeMediasViewController alloc] initWithHomeSectionInfo:[[HomeSectionInfo alloc] initWithHomeSection:homeSection]];
        viewController.liveLargeCell = YES;
        viewController.play_pageItem = [[PageItem alloc] initWithTitle:TitleForHomeSection(homeSection) image:nil];
        [viewControllers addObject:viewController];
    }
    
    if (self = [super initWithViewControllers:viewControllers.copy]) {
        self.title = NSLocalizedString(@"Lives", @"Title displayed at the top of the lives view");
    }
    return self;
}

#pragma mark SRGAnalyticsViewTracking protocol

- (NSString *)srg_pageViewTitle
{
    return NSLocalizedString(@"Lives", @"[Technical] Title for lives analytics measurements");
}

- (NSArray<NSString *> *)srg_pageViewLevels
{
    return @[ AnalyticsNameForPageType(AnalyticsPageTypeRadio) ];
}

#pragma mark PlayApplicationNavigation protocol

- (BOOL)openApplicationSectionInfo:(ApplicationSectionInfo *)applicationSectionInfo
{
    // TODO: select correct section.
    return NO;
}

@end
