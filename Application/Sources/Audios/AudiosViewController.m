//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "AudiosViewController.h"

#import "HomeViewController.h"
#import "NSBundle+PlaySRG.h"
#import "SettingsViewController.h"

@implementation AudiosViewController

#pragma mark Object lifecycle

- (instancetype)initWithRadioChannels:(NSArray<RadioChannel *> *)radioChannels
{
    NSAssert(radioChannels.count > 0, @"1 radio channel at least expected");
    
    NSMutableArray<UIViewController *> *viewControllers = [NSMutableArray array];
    for (RadioChannel *radioChannel in radioChannels) {
        HomeViewController *viewController = [[HomeViewController alloc] initWithRadioChannel:radioChannel];
        viewController.play_pageItem = [[PageItem alloc] initWithTitle:radioChannel.name image:RadioChannelLogo22Image(radioChannel)];
        [viewControllers addObject:viewController];
    }
    
    if (self = [super initWithViewControllers:viewControllers.copy]) {
        self.title = NSLocalizedString(@"Audio", @"Title displayed at the top of the audio view");
        
        UIBarButtonItem *settingsBarButtonItem = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"settings-22"]
                                                                               style:UIBarButtonItemStyleDone
                                                                              target:self
                                                                              action:@selector(settings:)];
        settingsBarButtonItem.accessibilityLabel = PlaySRGAccessibilityLocalizedString(@"Settings", @"Settings button label on home view");
        self.navigationItem.rightBarButtonItem = settingsBarButtonItem;
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

#pragma mark Actions

- (void)settings:(id)sender
{
    SettingsViewController *settingsViewController = [[SettingsViewController alloc] init];
    [self.navigationController pushViewController:settingsViewController animated:YES];
}

@end
