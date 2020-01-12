//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "AudiosViewController.h"

#import "HomeViewController.h"
#import "NSBundle+PlaySRG.h"

@interface AudiosViewController ()

@property (nonatomic)  NSArray<NSNumber *> *applicationSections;

@end

@implementation AudiosViewController

#pragma mark Object lifecycle

- (instancetype)initWithRadioChannels:(NSArray<RadioChannel *> *)radioChannels
{
    NSAssert(radioChannels.count > 0, @"1 radio channel at least expected");
    
    NSMutableSet<NSNumber *> *applicationSections = [NSMutableSet set];
    NSMutableArray<UIViewController *> *viewControllers = [NSMutableArray array];
    for (RadioChannel *radioChannel in radioChannels) {
        HomeViewController *viewController = [[HomeViewController alloc] initWithRadioChannel:radioChannel];
        viewController.play_pageItem = [[PageItem alloc] initWithTitle:radioChannel.name image:RadioChannelLogo22Image(radioChannel)];
        [viewControllers addObject:viewController];
        if ([viewController conformsToProtocol:@protocol(PlayApplicationNavigation)]) {
            [applicationSections addObjectsFromArray:((UIViewController<PlayApplicationNavigation> *)viewController).supportedApplicationSections];
        }
    }
    
    if (self = [super initWithViewControllers:viewControllers.copy]) {
        self.title = NSLocalizedString(@"Audio", @"Title displayed at the top of the audio view");
        self.applicationSections = applicationSections.allObjects;
    }
    return self;
}

#pragma mark SRGAnalyticsViewTracking protocol

- (NSString *)srg_pageViewTitle
{
    return NSLocalizedString(@"Audio", @"[Technical] Title for audio analytics measurements");
}

- (NSArray<NSString *> *)srg_pageViewLevels
{
    return @[ AnalyticsNameForPageType(AnalyticsPageTypeRadio) ];
}

#pragma mark PlayApplicationNavigation protocol

- (NSArray<NSNumber *> *)supportedApplicationSections
{
    return self.applicationSections;
}

- (void)openApplicationSectionInfo:(ApplicationSectionInfo *)applicationSectionInfo
{
    if ([self.supportedApplicationSections containsObject:@(applicationSectionInfo.applicationSection)]) {
        // TODO: select correct section and forward to audio home.
    }
}

@end
