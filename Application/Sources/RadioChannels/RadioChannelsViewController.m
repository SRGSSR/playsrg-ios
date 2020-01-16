//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "RadioChannelsViewController.h"

#import "HomeViewController.h"
#import "NSBundle+PlaySRG.h"

#import <libextobjc/libextobjc.h>

@implementation RadioChannelsViewController

#pragma mark Object lifecycle

- (instancetype)initWithRadioChannels:(NSArray<RadioChannel *> *)radioChannels
{
    NSAssert(radioChannels.count > 0, @"1 radio channel at least expected");
    
    NSMutableArray<UIViewController *> *viewControllers = [NSMutableArray array];
    for (RadioChannel *radioChannel in radioChannels) {
        HomeViewController *viewController = [[HomeViewController alloc] initWithRadioChannel:radioChannel];
        viewController.play_pageItem = [[PageItem alloc] initWithTitle:radioChannel.name image:RadioChannelLogo22Image(radioChannel) applicationSection:ApplicationSectionAudios radioChannel:radioChannel];
        [viewControllers addObject:viewController];
    }
    
    if (self = [super initWithViewControllers:viewControllers.copy]) {
        self.title = NSLocalizedString(@"Audios", @"Title displayed at the top of the audio view");
    }
    return self;
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
    
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"%K == %@", @keypath(UIViewController.new, play_pageItem.radioChannel), applicationSectionInfo.radioChannel];
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
