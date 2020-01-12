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

- (instancetype)initWithSections:(NSArray<NSNumber *> *)sections
{
    NSAssert(sections.count > 0, @"1 live section at least expected");
    
    NSMutableArray<UIViewController *> *viewControllers = [NSMutableArray array];
    for (NSNumber *sectionNumber in sections) {
        HomeSection section = sectionNumber.integerValue;
        HomeMediasViewController *viewController = [[HomeMediasViewController alloc] initWithHomeSectionInfo:[[HomeSectionInfo alloc] initWithHomeSection:section]];
        viewController.liveLargeCell = YES;
        viewController.play_pageItem = [[PageItem alloc] initWithTitle:TitleForHomeSection(section) image:nil];
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

- (NSArray<NSNumber *> *)supportedApplicationSections
{
    return @[];
}

- (void)openApplicationSectionInfo:(ApplicationSectionInfo *)applicationSectionInfo
{
    if ([self.supportedApplicationSections containsObject:@(applicationSectionInfo.applicationSection)]) {
        // TODO: select correct section.
    }
}

@end
