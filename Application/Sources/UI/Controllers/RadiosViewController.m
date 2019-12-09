//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "RadiosViewController.h"

#import "HomeViewController.h"

@implementation RadiosViewController

#pragma mark Object lifecycle

- (instancetype)initWithRadioChannels:(NSArray<RadioChannel *> *)radioChannels
{
    NSAssert(radioChannels.count > 0, @"1 radio channel at least expected");
    
    NSMutableArray<UIViewController *> *viewControllers = [NSMutableArray array];
    for (RadioChannel *radioChannel in radioChannels) {
        HomeViewController *homeViewController = [[HomeViewController alloc] initWithRadioChannel:radioChannel];
        homeViewController.play_pageItem = [[PageItem alloc] initWithTitle:radioChannel.name image:RadioChannelLogo22Image(radioChannel)];
        [viewControllers addObject:homeViewController];
    }
    
    if (self = [super initWithViewControllers:viewControllers.copy]) {
        self.title = (radioChannels.count > 1) ? NSLocalizedString(@"Radios", @"Title displayed at the top of the radios view") : NSLocalizedString(@"Radio", @"Title displayed at the top of the radios view");
    }
    return self;
}

#pragma mark SRGAnalyticsViewTracking protocol

- (NSString *)srg_pageViewTitle
{
    return NSLocalizedString(@"Radios", @"[Technical] Title for radios analytics measurements");
}

- (NSArray<NSString *> *)srg_pageViewLevels
{
    return @[ AnalyticsNameForPageType(AnalyticsPageTypeRadio) ];
}

@end
