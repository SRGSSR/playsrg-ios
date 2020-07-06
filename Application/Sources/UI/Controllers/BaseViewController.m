//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "BaseViewController.h"

#import "ActivityItemSource.h"
#import "AnalyticsConstants.h"
#import "ApplicationConfiguration.h"
#import "Banner.h"
#import "Download.h"
#import "Favorites.h"
#import "GoogleCast.h"
#import "HomeTopicViewController.h"
#import "MediaPlayerViewController.h"
#import "MediaPreviewViewController.h"
#import "ModuleViewController.h"
#import "NSBundle+PlaySRG.h"
#import "PlayErrors.h"
#import "Previewing.h"
#import "ShowViewController.h"
#import "UIViewController+PlaySRG.h"
#import "UIViewController+PlaySRG_Private.h"
#import "WatchLater.h"

#import <objc/runtime.h>
#import <libextobjc/libextobjc.h>
#import <SRGAnalytics/SRGAnalytics.h>

// Inner class conforming to `UIPopoverPresentationControllerDelegate` to avoid having `BaseViewController` conform to
// it.
@interface BaseViewControllerPresentationControllerDelegate : NSObject <UIPopoverPresentationControllerDelegate>

@end

@implementation BaseViewControllerPresentationControllerDelegate

#pragma mark UIPopoverPresentationControllerDelegate protocol

- (UIModalPresentationStyle)adaptivePresentationStyleForPresentationController:(UIPresentationController *)controller traitCollection:(UITraitCollection *)traitCollection
{
    return UIModalPresentationFormSheet;
}

@end

@interface BaseViewController ()

@property (nonatomic, readonly) BaseViewControllerPresentationControllerDelegate *presentationControllerDelegate;

@end

@implementation BaseViewController

@synthesize presentationControllerDelegate = _presentationControllerDelegate;

#pragma mark Getters and setters

- (UIViewController *)previewContextViewController
{
    return self;
}

- (BaseViewControllerPresentationControllerDelegate *)presentationControllerDelegate
{
    if (! _presentationControllerDelegate) {
        _presentationControllerDelegate = [[BaseViewControllerPresentationControllerDelegate alloc] init];
    }
    return _presentationControllerDelegate;
}

#pragma mark Accessibility

- (BOOL)accessibilityPerformEscape
{
    if (self.navigationController.viewControllers.count > 1) {
        [self.navigationController popViewControllerAnimated:YES];
        return YES;
    }
    else if (self.presentingViewController) {
        [self dismissViewControllerAnimated:YES completion:nil];
        return YES;
    }
    else {
        return NO;
    }
}

#pragma mark Context menus

- (UIMenu *)contextMenuForMedia:(SRGMedia *)media API_AVAILABLE(ios(13.0))
{
    NSMutableArray<UIMenuElement *> *menuActions = [NSMutableArray array];
    
    if (WatchLaterCanStoreMediaMetadata(media)) {
        BOOL inWatchLaterList = WatchLaterContainsMediaMetadata(media);
        UIAction *watchLaterAction = [UIAction actionWithTitle:inWatchLaterList ? NSLocalizedString(@"Remove from \"Watch later\"", @"Context menu action to remove a media from the watch later list") : NSLocalizedString(@"Add to \"Watch later\"", @"Context menu action to add a media to the watch later list") image:inWatchLaterList ? [UIImage imageNamed:@"watch_later_full-22"] : [UIImage imageNamed:@"watch_later-22"] identifier:nil handler:^(__kindof UIAction * _Nonnull action) {
            WatchLaterToggleMediaMetadata(media, ^(BOOL added, NSError * _Nullable error) {
                if (! error) {
                    AnalyticsTitle analyticsTitle = added ? AnalyticsTitleWatchLaterAdd : AnalyticsTitleWatchLaterRemove;
                    SRGAnalyticsHiddenEventLabels *labels = [[SRGAnalyticsHiddenEventLabels alloc] init];
                    labels.source = AnalyticsSourcePeekMenu;
                    labels.value = media.URN;
                    [SRGAnalyticsTracker.sharedTracker trackHiddenEventWithName:analyticsTitle labels:labels];
                    
                    [Banner showWatchLaterAdded:added forItemWithName:media.title inViewController:nil /* Not 'self' since dismissed */];
                }
            });
        }];
        if (inWatchLaterList) {
            watchLaterAction.attributes = UIMenuElementAttributesDestructive;
        }
        [menuActions addObject:watchLaterAction];
    }
    
    BOOL downloadable = [Download canDownloadMedia:media];
    if (downloadable) {
        Download *download = [Download downloadForMedia:media];
        BOOL downloaded = (download != nil);
        UIAction *downloadAction = [UIAction actionWithTitle:downloaded ? NSLocalizedString(@"Remove from downloads", @"Context menu action to remove a media from the downloads") : NSLocalizedString(@"Add to downloads", @"Context menu action to add a media to the downloads") image:downloaded ? [UIImage imageNamed:@"downloadable_full-22"] : [UIImage imageNamed:@"downloadable-22"] identifier:nil handler:^(__kindof UIAction * _Nonnull action) {
            if (downloaded) {
                [Download removeDownload:download];
            }
            else {
                [Download addDownloadForMedia:media];
            }
            
            // Use !downloaded since the status has been reversed
            AnalyticsTitle analyticsTitle = ! downloaded ? AnalyticsTitleDownloadAdd : AnalyticsTitleDownloadRemove;
            SRGAnalyticsHiddenEventLabels *labels = [[SRGAnalyticsHiddenEventLabels alloc] init];
            labels.source = AnalyticsSourcePeekMenu;
            labels.value = media.URN;
            [SRGAnalyticsTracker.sharedTracker trackHiddenEventWithName:analyticsTitle labels:labels];
        }];
        if (downloaded) {
            downloadAction.attributes = UIMenuElementAttributesDestructive;
        }
        [menuActions addObject:downloadAction];
    }
    
    NSURL *sharingURL = [ApplicationConfiguration.sharedApplicationConfiguration sharingURLForMediaMetadata:media atTime:kCMTimeZero];
    if (sharingURL) {
        UIAction *shareAction = [UIAction actionWithTitle:NSLocalizedString(@"Share", @"Context menu action to share a media") image:[UIImage imageNamed:@"share-22"] identifier:nil handler:^(__kindof UIAction * _Nonnull action) {
            ActivityItemSource *activityItemSource = [[ActivityItemSource alloc] initWithMedia:media URL:sharingURL];
            UIActivityViewController *activityViewController = [[UIActivityViewController alloc] initWithActivityItems:@[ activityItemSource ] applicationActivities:nil];
            activityViewController.excludedActivityTypes = @[ UIActivityTypePrint,
                                                              UIActivityTypeAssignToContact,
                                                              UIActivityTypeSaveToCameraRoll,
                                                              UIActivityTypePostToFlickr,
                                                              UIActivityTypePostToVimeo,
                                                              UIActivityTypePostToTencentWeibo ];
            activityViewController.completionWithItemsHandler = ^(UIActivityType __nullable activityType, BOOL completed, NSArray * __nullable returnedItems, NSError * __nullable activityError) {
                if (! completed) {
                    return;
                }
                
                SRGAnalyticsHiddenEventLabels *labels = [[SRGAnalyticsHiddenEventLabels alloc] init];
                labels.type = activityType;
                labels.source = AnalyticsSourcePeekMenu;
                labels.value = media.URN;
                labels.extraValue1 = AnalyticsTypeValueSharingContent;
                [SRGAnalyticsTracker.sharedTracker trackHiddenEventWithName:AnalyticsTitleSharingMedia labels:labels];
                
                if ([activityType isEqualToString:UIActivityTypeCopyToPasteboard]) {
                    [Banner showWithStyle:BannerStyleInfo
                                  message:NSLocalizedString(@"The content has been copied to the clipboard.", @"Message displayed when some content (media, show, etc.) has been copied to the clipboard")
                                    image:nil
                                   sticky:NO
                         inViewController:self];
                }
            };
            
            UIPopoverPresentationController *popoverPresentationController = activityViewController.popoverPresentationController;
            popoverPresentationController.sourceView = self.view;
            popoverPresentationController.delegate = self.presentationControllerDelegate;
            
            [self presentViewController:activityViewController animated:YES completion:nil];
        }];
        [menuActions addObject:shareAction];
    }
    
    if (self.navigationController && ! ApplicationConfiguration.sharedApplicationConfiguration.moreEpisodesHidden && media.show) {
        UIAction *moreEpisodesAction = [UIAction actionWithTitle:NSLocalizedString(@"More episodes", @"Context menu action to open more episodes associated with a media") image:[UIImage imageNamed:@"episodes-22"] identifier:nil handler:^(__kindof UIAction * _Nonnull action) {
            ShowViewController *showViewController = [[ShowViewController alloc] initWithShow:media.show fromPushNotification:NO];
            [self.navigationController pushViewController:showViewController animated:YES];
        }];
        moreEpisodesAction.accessibilityLabel = PlaySRGAccessibilityLocalizedString(@"More episodes", @"Button label to open the show episode page from the preview window");
        [menuActions addObject:moreEpisodesAction];
    }
    
    return [UIMenu menuWithTitle:@"" children:menuActions.copy];
}

- (UIMenu *)contextMenuForModule:(SRGModule *)module API_AVAILABLE(ios(13.0))
{
    NSMutableArray<UIMenuElement *> *menuActions = [NSMutableArray array];
    
    NSURL *sharingURL = [ApplicationConfiguration.sharedApplicationConfiguration sharingURLForModule:module];
    if (sharingURL) {
        UIAction *shareAction = [UIAction actionWithTitle:NSLocalizedString(@"Share", @"Context menu action to share a module") image:[UIImage imageNamed:@"share-22"] identifier:nil handler:^(__kindof UIAction * _Nonnull action) {
            ActivityItemSource *activityItemSource = [[ActivityItemSource alloc] initWithModule:module URL:sharingURL];
            UIActivityViewController *activityViewController = [[UIActivityViewController alloc] initWithActivityItems:@[ activityItemSource ] applicationActivities:nil];
            activityViewController.excludedActivityTypes = @[ UIActivityTypePrint,
                                                              UIActivityTypeAssignToContact,
                                                              UIActivityTypeSaveToCameraRoll,
                                                              UIActivityTypePostToFlickr,
                                                              UIActivityTypePostToVimeo,
                                                              UIActivityTypePostToTencentWeibo ];
            activityViewController.completionWithItemsHandler = ^(UIActivityType __nullable activityType, BOOL completed, NSArray * __nullable returnedItems, NSError * __nullable activityError) {
                if (! completed) {
                    return;
                }
                
                SRGAnalyticsHiddenEventLabels *labels = [[SRGAnalyticsHiddenEventLabels alloc] init];
                labels.type = activityType;
                labels.source = AnalyticsSourcePeekMenu;
                labels.value = module.URN;
                [SRGAnalyticsTracker.sharedTracker trackHiddenEventWithName:AnalyticsTitleSharingModule labels:labels];
                
                if ([activityType isEqualToString:UIActivityTypeCopyToPasteboard]) {
                    [Banner showWithStyle:BannerStyleInfo
                                  message:NSLocalizedString(@"The content has been copied to the clipboard.", @"Message displayed when some content (media, show, etc.) has been copied to the clipboard")
                                    image:nil
                                   sticky:NO
                         inViewController:self];
                }
            };
            
            UIPopoverPresentationController *popoverPresentationController = activityViewController.popoverPresentationController;
            popoverPresentationController.sourceView = self.view;
            popoverPresentationController.delegate = self.presentationControllerDelegate;
            
            [self presentViewController:activityViewController animated:YES completion:nil];
        }];
        [menuActions addObject:shareAction];
    }
    
    return [UIMenu menuWithTitle:@"" children:menuActions.copy];
}

- (UIMenu *)contextMenuForShow:(SRGShow *)show API_AVAILABLE(ios(13.0))
{
    NSMutableArray<UIMenuElement *> *menuActions = [NSMutableArray array];
    
    BOOL isFavorite = FavoritesContainsShow(show);
    UIAction *favoriteAction = [UIAction actionWithTitle:isFavorite ? NSLocalizedString(@"Remove from favorites", @"Context menu action to remove a show from favorites") : NSLocalizedString(@"Add to favorites", @"Context menu action to add a show to favorites") image:isFavorite ? [UIImage imageNamed:@"favorite_full-22"] : [UIImage imageNamed:@"favorite-22"] identifier:nil handler:^(__kindof UIAction * _Nonnull action) {
        FavoritesToggleShow(show);
        
        // Use !isFavorite since favorite status has been reversed
        AnalyticsTitle analyticsTitle = ! isFavorite ? AnalyticsTitleFavoriteAdd : AnalyticsTitleFavoriteRemove;
        SRGAnalyticsHiddenEventLabels *labels = [[SRGAnalyticsHiddenEventLabels alloc] init];
        labels.source = AnalyticsSourcePeekMenu;
        labels.value = show.URN;
        [SRGAnalyticsTracker.sharedTracker trackHiddenEventWithName:analyticsTitle labels:labels];
        
        [Banner showFavorite:! isFavorite forItemWithName:show.title inViewController:self];
    }];
    if (isFavorite) {
        favoriteAction.attributes = UIMenuElementAttributesDestructive;
    }
    [menuActions addObject:favoriteAction];
    
    NSURL *sharingURL = [ApplicationConfiguration.sharedApplicationConfiguration sharingURLForShow:show];
    if (sharingURL) {
        UIAction *shareAction = [UIAction actionWithTitle:NSLocalizedString(@"Share", @"Context menu action to share a show") image:[UIImage imageNamed:@"share-22"] identifier:nil handler:^(__kindof UIAction * _Nonnull action) {
            ActivityItemSource *activityItemSource = [[ActivityItemSource alloc] initWithShow:show URL:sharingURL];
            UIActivityViewController *activityViewController = [[UIActivityViewController alloc] initWithActivityItems:@[ activityItemSource ] applicationActivities:nil];
            activityViewController.excludedActivityTypes = @[ UIActivityTypePrint,
                                                              UIActivityTypeAssignToContact,
                                                              UIActivityTypeSaveToCameraRoll,
                                                              UIActivityTypePostToFlickr,
                                                              UIActivityTypePostToVimeo,
                                                              UIActivityTypePostToTencentWeibo ];
            activityViewController.completionWithItemsHandler = ^(UIActivityType __nullable activityType, BOOL completed, NSArray * __nullable returnedItems, NSError * __nullable activityError) {
                if (! completed) {
                    return;
                }
                
                SRGAnalyticsHiddenEventLabels *labels = [[SRGAnalyticsHiddenEventLabels alloc] init];
                labels.type = activityType;
                labels.source = AnalyticsSourcePeekMenu;
                labels.value = show.URN;
                [SRGAnalyticsTracker.sharedTracker trackHiddenEventWithName:AnalyticsTitleSharingShow labels:labels];
                
                if ([activityType isEqualToString:UIActivityTypeCopyToPasteboard]) {
                    [Banner showWithStyle:BannerStyleInfo
                                  message:NSLocalizedString(@"The content has been copied to the clipboard.", @"Message displayed when some content (media, show, etc.) has been copied to the clipboard")
                                    image:nil
                                   sticky:NO
                         inViewController:self];
                }
            };
            
            UIPopoverPresentationController *popoverPresentationController = activityViewController.popoverPresentationController;
            popoverPresentationController.sourceView = self.view;
            popoverPresentationController.delegate = self.presentationControllerDelegate;
            
            [self presentViewController:activityViewController animated:YES completion:nil];
        }];
        [menuActions addObject:shareAction];
    }
    
    return [UIMenu menuWithTitle:@"" children:menuActions.copy];
}

#pragma mark UIContextMenuInteractionDelegate protocol

- (UIContextMenuConfiguration *)contextMenuInteraction:(UIContextMenuInteraction *)interaction configurationForMenuAtLocation:(CGPoint)location API_AVAILABLE(ios(13.0))
{
    UIView *sourceView = interaction.view;
    if (! [sourceView conformsToProtocol:@protocol(Previewing)]) {
        return nil;
    }
    
    id previewObject = [(id<Previewing>)sourceView previewObject];
    if (! previewObject) {
        return nil;
    }
    
    if ([previewObject isKindOfClass:SRGMedia.class]) {
        return [UIContextMenuConfiguration configurationWithIdentifier:nil previewProvider:^UIViewController * _Nullable{
            return [[MediaPreviewViewController alloc] initWithMedia:previewObject];
        } actionProvider:^UIMenu * _Nullable(NSArray<UIMenuElement *> * _Nonnull suggestedActions) {
            return [self contextMenuForMedia:previewObject];
        }];
    }
    else if ([previewObject isKindOfClass:SRGModule.class]) {
        return [UIContextMenuConfiguration configurationWithIdentifier:nil previewProvider:^UIViewController * _Nullable{
            return [[ModuleViewController alloc] initWithModule:previewObject];
        } actionProvider:^UIMenu * _Nullable(NSArray<UIMenuElement *> * _Nonnull suggestedActions) {
            return [self contextMenuForModule:previewObject];
        }];
    }
    else if ([previewObject isKindOfClass:SRGShow.class]) {
        return [UIContextMenuConfiguration configurationWithIdentifier:nil previewProvider:^UIViewController * _Nullable{
            return [[ShowViewController alloc] initWithShow:previewObject fromPushNotification:NO];
        } actionProvider:^UIMenu * _Nullable(NSArray<UIMenuElement *> * _Nonnull suggestedActions) {
            return [self contextMenuForShow:previewObject];
        }];
    }
    else {
        return nil;
    }
}

- (void)contextMenuInteraction:(UIContextMenuInteraction *)interaction willPerformPreviewActionForMenuWithConfiguration:(UIContextMenuConfiguration *)configuration animator:(id<UIContextMenuInteractionCommitAnimating>)animator API_AVAILABLE(ios(13.0))
{
    UIViewController *viewController = animator.previewViewController;
    animator.preferredCommitStyle = UIContextMenuInteractionCommitStylePop;
    [animator addCompletion:^{
        if ([viewController isKindOfClass:MediaPreviewViewController.class]) {
            MediaPreviewViewController *mediaPreviewViewController = (MediaPreviewViewController *)viewController;
            [self play_presentMediaPlayerFromLetterboxController:mediaPreviewViewController.letterboxController withAirPlaySuggestions:NO fromPushNotification:NO animated:YES completion:nil];
        }
        else if ([viewController isKindOfClass:ModuleViewController.class]
                    || [viewController isKindOfClass:ShowViewController.class]
                    || [viewController isKindOfClass:HomeTopicViewController.class]) {
            [self.navigationController pushViewController:viewController animated:YES];
        }
    }];
}

- (UITargetedPreview *)contextMenuInteraction:(UIContextMenuInteraction *)interaction previewForHighlightingMenuWithConfiguration:(UIContextMenuConfiguration *)configuration API_AVAILABLE(ios(13.0))
{
    UIPreviewParameters *previewParameters = [[UIPreviewParameters alloc] init];
    previewParameters.backgroundColor = self.view.backgroundColor;
    return [[UITargetedPreview alloc] initWithView:interaction.view parameters:previewParameters];
}

#pragma mark UIViewControllerPreviewingDelegate protocol

- (UIViewController *)previewingContext:(id<UIViewControllerPreviewing>)previewingContext viewControllerForLocation:(CGPoint)location
{
    UIView *sourceView = [previewingContext sourceView];
    if (! [sourceView conformsToProtocol:@protocol(Previewing)]) {
        return nil;
    }
    
    id previewObject = [(id<Previewing>)sourceView previewObject];
    if (! previewObject) {
        return nil;
    }
    
    UIViewController *viewController = nil;
    if ([previewObject isKindOfClass:SRGMedia.class]) {
        viewController = [[MediaPreviewViewController alloc] initWithMedia:previewObject];
    }
    else if ([previewObject isKindOfClass:SRGModule.class]) {
        viewController = [[ModuleViewController alloc] initWithModule:previewObject];
    }
    else if ([previewObject isKindOfClass:SRGShow.class]) {
        viewController = [[ShowViewController alloc] initWithShow:previewObject fromPushNotification:NO];
    }
    else {
        return nil;
    }
    
    viewController.play_previewingContext = previewingContext;
    return viewController;
}

- (void)previewingContext:(id<UIViewControllerPreviewing>)previewingContext commitViewController:(UIViewController *)viewControllerToCommit
{
    if ([viewControllerToCommit isKindOfClass:MediaPreviewViewController.class]) {
        MediaPreviewViewController *mediaPreviewViewController = (MediaPreviewViewController *)viewControllerToCommit;
        [self play_presentMediaPlayerFromLetterboxController:mediaPreviewViewController.letterboxController withAirPlaySuggestions:NO fromPushNotification:NO animated:YES completion:nil];
    }
    else if ([viewControllerToCommit isKindOfClass:ModuleViewController.class]
                || [viewControllerToCommit isKindOfClass:ShowViewController.class]
                || [viewControllerToCommit isKindOfClass:HomeTopicViewController.class]) {
        [self.navigationController pushViewController:viewControllerToCommit animated:YES];
    }
}

#pragma mark 3D Touch fallback

- (void)handleLongPress:(UIGestureRecognizer *)gestureRecognizer
{
    UIView *sourceView = gestureRecognizer.view;
    if (! [sourceView conformsToProtocol:@protocol(Previewing)]) {
        return;
    }
    
    id previewObject = [(id<Previewing>)sourceView previewObject];
    if (! previewObject) {
        return;
    }
    
    UIAlertController *alertController = nil;
    
    if ([previewObject isKindOfClass:SRGMedia.class]) {
        SRGMedia *media = previewObject;
        
        NSString *message = (media.show.title && ! [media.title containsString:media.show.title]) ? media.show.title : nil;
        alertController = [UIAlertController alertControllerWithTitle:media.title message:message preferredStyle:UIAlertControllerStyleActionSheet];
        
        if (WatchLaterCanStoreMediaMetadata(media)) {
            BOOL inWatchLaterList = WatchLaterContainsMediaMetadata(media);
            [alertController addAction:[UIAlertAction actionWithTitle:inWatchLaterList ? NSLocalizedString(@"Remove from \"Watch later\"", @"Button label to remove a media from the watch later list, from the media long-press menu") : NSLocalizedString(@"Add to \"Watch later\"", @"Button label to add a media to the watch later list, from the media long-press menu") style:inWatchLaterList ? UIAlertActionStyleDestructive : UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                WatchLaterToggleMediaMetadata(media, ^(BOOL added, NSError * _Nullable error) {
                    if (! error) {
                        AnalyticsTitle analyticsTitle = added ? AnalyticsTitleWatchLaterAdd : AnalyticsTitleWatchLaterRemove;
                        SRGAnalyticsHiddenEventLabels *labels = [[SRGAnalyticsHiddenEventLabels alloc] init];
                        labels.source = AnalyticsSourceLongPress;
                        labels.value = media.URN;
                        [SRGAnalyticsTracker.sharedTracker trackHiddenEventWithName:analyticsTitle labels:labels];
                        
                        [Banner showWatchLaterAdded:added forItemWithName:media.title inViewController:self];
                    }
                });
            }]];
        }
        
        BOOL downloadable = [Download canDownloadMedia:media];
        if (downloadable) {
            Download *download = [Download downloadForMedia:media];
            BOOL downloaded = (download != nil);
            [alertController addAction:[UIAlertAction actionWithTitle:downloaded ? NSLocalizedString(@"Remove from downloads", @"Button label to remove a download from the media long-press menu") : NSLocalizedString(@"Add to downloads", @"Button label to add a download from the media long-press menu") style:downloaded ? UIAlertActionStyleDestructive : UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                if (downloaded) {
                    [Download removeDownload:download];
                }
                else {
                    [Download addDownloadForMedia:media];
                }
                
                // Use !downloaded since the status has been reversed
                AnalyticsTitle analyticsTitle = ! downloaded ? AnalyticsTitleDownloadAdd : AnalyticsTitleDownloadRemove;
                SRGAnalyticsHiddenEventLabels *labels = [[SRGAnalyticsHiddenEventLabels alloc] init];
                labels.source = AnalyticsSourceLongPress;
                labels.value = media.URN;
                [SRGAnalyticsTracker.sharedTracker trackHiddenEventWithName:analyticsTitle labels:labels];
            }]];
        }
        
        NSURL *sharingURL = [ApplicationConfiguration.sharedApplicationConfiguration sharingURLForMediaMetadata:media atTime:kCMTimeZero];
        if (sharingURL) {
            [alertController addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Share", @"Button label of the sharing choice in the media long-press menu") style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                ActivityItemSource *activityItemSource = [[ActivityItemSource alloc] initWithMedia:media URL:sharingURL];
                UIActivityViewController *activityViewController = [[UIActivityViewController alloc] initWithActivityItems:@[ activityItemSource ] applicationActivities:nil];
                activityViewController.excludedActivityTypes = @[ UIActivityTypePrint,
                                                                  UIActivityTypeAssignToContact,
                                                                  UIActivityTypeSaveToCameraRoll,
                                                                  UIActivityTypePostToFlickr,
                                                                  UIActivityTypePostToVimeo,
                                                                  UIActivityTypePostToTencentWeibo ];
                activityViewController.completionWithItemsHandler = ^(UIActivityType __nullable activityType, BOOL completed, NSArray * __nullable returnedItems, NSError * __nullable activityError) {
                    if (! completed) {
                        return;
                    }
                    
                    SRGAnalyticsHiddenEventLabels *labels = [[SRGAnalyticsHiddenEventLabels alloc] init];
                    labels.type = activityType;
                    labels.source = AnalyticsSourceLongPress;
                    labels.value = media.URN;
                    labels.extraValue1 = AnalyticsTypeValueSharingContent;
                    [SRGAnalyticsTracker.sharedTracker trackHiddenEventWithName:AnalyticsTitleSharingMedia labels:labels];
                    
                    if ([activityType isEqualToString:UIActivityTypeCopyToPasteboard]) {
                        [Banner showWithStyle:BannerStyleInfo
                                      message:NSLocalizedString(@"The content has been copied to the clipboard.", @"Message displayed when some content (media, show, etc.) has been copied to the clipboard")
                                        image:nil
                                       sticky:NO
                             inViewController:self];
                    }
                };
                
                UIPopoverPresentationController *popoverPresentationController = activityViewController.popoverPresentationController;
                popoverPresentationController.sourceView = sourceView;
                popoverPresentationController.sourceRect = sourceView.bounds;
                
                [self presentViewController:activityViewController animated:YES completion:nil];
            }]];
        }
        
        if (self.navigationController && ! ApplicationConfiguration.sharedApplicationConfiguration.moreEpisodesHidden && media.show) {
            UIAlertAction *moreEpisodesAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"More episodes", @"Button label to open the show episode page from the long-press menu") style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                ShowViewController *showViewController = [[ShowViewController alloc] initWithShow:media.show fromPushNotification:NO];
                [self.navigationController pushViewController:showViewController animated:YES];
            }];
            moreEpisodesAction.accessibilityLabel = PlaySRGAccessibilityLocalizedString(@"More episodes", @"Button label to open the show episode page from the preview window");
            [alertController addAction:moreEpisodesAction];
        }
        
        [alertController addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Open", @"Button label to open a media from the start from the long-press menu") style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            void (^openPlayer)(void) = ^{
                MediaPlayerViewController *mediaPlayerViewController = [[MediaPlayerViewController alloc] initWithMedia:media position:nil fromPushNotification:NO];
                mediaPlayerViewController.modalPresentationStyle = UIModalPresentationFullScreen;
                [self presentViewController:mediaPlayerViewController animated:YES completion:nil];
            };
            
            if (@available(iOS 13, *)) {
                [AVAudioSession.sharedInstance prepareRouteSelectionForPlaybackWithCompletionHandler:^(BOOL shouldStartPlayback, AVAudioSessionRouteSelection routeSelection) {
                    if (shouldStartPlayback && routeSelection != AVAudioSessionRouteSelectionNone) {
                        openPlayer();
                    }
                }];
            }
            else {
                openPlayer();
            }
        }]];
        [alertController addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Cancel", @"Label of the button to close the media long-press menu") style:UIAlertActionStyleCancel handler:nil]];
    }
    else if ([previewObject isKindOfClass:SRGModule.class]) {
        SRGModule *module = previewObject;
        
        alertController = [UIAlertController alertControllerWithTitle:module.title message:nil preferredStyle:UIAlertControllerStyleActionSheet];
        
        NSURL *sharingURL = [ApplicationConfiguration.sharedApplicationConfiguration sharingURLForModule:module];
        if (sharingURL) {
            [alertController addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Share", @"Button label of the sharing choice in the module long-press menu") style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                ActivityItemSource *activityItemSource = [[ActivityItemSource alloc] initWithModule:module URL:sharingURL];
                UIActivityViewController *activityViewController = [[UIActivityViewController alloc] initWithActivityItems:@[ activityItemSource ] applicationActivities:nil];
                activityViewController.excludedActivityTypes = @[ UIActivityTypePrint,
                                                                  UIActivityTypeAssignToContact,
                                                                  UIActivityTypeSaveToCameraRoll,
                                                                  UIActivityTypePostToFlickr,
                                                                  UIActivityTypePostToVimeo,
                                                                  UIActivityTypePostToTencentWeibo ];
                activityViewController.completionWithItemsHandler = ^(UIActivityType __nullable activityType, BOOL completed, NSArray * __nullable returnedItems, NSError * __nullable activityError) {
                    if (! completed) {
                        return;
                    }
                    
                    SRGAnalyticsHiddenEventLabels *labels = [[SRGAnalyticsHiddenEventLabels alloc] init];
                    labels.type = activityType;
                    labels.source = AnalyticsSourceLongPress;
                    labels.value = module.URN;
                    [SRGAnalyticsTracker.sharedTracker trackHiddenEventWithName:AnalyticsTitleSharingModule labels:labels];
                    
                    if ([activityType isEqualToString:UIActivityTypeCopyToPasteboard]) {
                        [Banner showWithStyle:BannerStyleInfo
                                      message:NSLocalizedString(@"The content has been copied to the clipboard.", @"Message displayed when some content (media, show, etc.) has been copied to the clipboard")
                                        image:nil
                                       sticky:NO
                             inViewController:self];
                    }
                };
                [self presentViewController:activityViewController animated:YES completion:nil];
            }]];
        }
        
        if (self.navigationController) {
            [alertController addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Open", @"Button label to open a module from the from the long-press menu") style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                ModuleViewController *moduleViewController = [[ModuleViewController alloc] initWithModule:module];
                [self.navigationController pushViewController:moduleViewController animated:YES];
            }]];
        }
        [alertController addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Cancel", @"Label of the button to close the module long-press menu") style:UIAlertActionStyleCancel handler:nil]];
    }
    else if ([previewObject isKindOfClass:SRGShow.class]) {
        SRGShow *show = previewObject;
        
        alertController = [UIAlertController alertControllerWithTitle:show.title message:nil preferredStyle:UIAlertControllerStyleActionSheet];
        
        BOOL isFavorite = FavoritesContainsShow(show);
        [alertController addAction:[UIAlertAction actionWithTitle:isFavorite ? NSLocalizedString(@"Remove from favorites", @"Button label to remove a show from favorites in the show long-press menu") : NSLocalizedString(@"Add to favorites", @"Button label to add a show to favorites in the show long-press menu") style:isFavorite ? UIAlertActionStyleDestructive : UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            FavoritesToggleShow(show);
            
            // Use !isFavorite since favorite status has been reversed
            AnalyticsTitle analyticsTitle = ! isFavorite ? AnalyticsTitleFavoriteAdd : AnalyticsTitleFavoriteRemove;
            SRGAnalyticsHiddenEventLabels *labels = [[SRGAnalyticsHiddenEventLabels alloc] init];
            labels.source = AnalyticsSourceLongPress;
            labels.value = show.URN;
            [SRGAnalyticsTracker.sharedTracker trackHiddenEventWithName:analyticsTitle labels:labels];
            
            [Banner showFavorite:! isFavorite forItemWithName:show.title inViewController:self];
        }]];
        
        NSURL *sharingURL = [ApplicationConfiguration.sharedApplicationConfiguration sharingURLForShow:show];
        if (sharingURL) {
            [alertController addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Share", @"Button label of the sharing choice in the show long-press menu") style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                ActivityItemSource *activityItemSource = [[ActivityItemSource alloc] initWithShow:show URL:sharingURL];
                UIActivityViewController *activityViewController = [[UIActivityViewController alloc] initWithActivityItems:@[ activityItemSource ] applicationActivities:nil];
                activityViewController.excludedActivityTypes = @[ UIActivityTypePrint,
                                                                  UIActivityTypeAssignToContact,
                                                                  UIActivityTypeSaveToCameraRoll,
                                                                  UIActivityTypePostToFlickr,
                                                                  UIActivityTypePostToVimeo,
                                                                  UIActivityTypePostToTencentWeibo ];
                activityViewController.completionWithItemsHandler = ^(UIActivityType __nullable activityType, BOOL completed, NSArray * __nullable returnedItems, NSError * __nullable activityError) {
                    if (! completed) {
                        return;
                    }
                    
                    SRGAnalyticsHiddenEventLabels *labels = [[SRGAnalyticsHiddenEventLabels alloc] init];
                    labels.type = activityType;
                    labels.source = AnalyticsSourceLongPress;
                    labels.value = show.URN;
                    [SRGAnalyticsTracker.sharedTracker trackHiddenEventWithName:AnalyticsTitleSharingShow labels:labels];
                    
                    if ([activityType isEqualToString:UIActivityTypeCopyToPasteboard]) {
                        [Banner showWithStyle:BannerStyleInfo
                                      message:NSLocalizedString(@"The content has been copied to the clipboard.", @"Message displayed when some content (media, show, etc.) has been copied to the clipboard")
                                        image:nil
                                       sticky:NO
                             inViewController:self];
                    }
                };
                
                UIPopoverPresentationController *popoverPresentationController = activityViewController.popoverPresentationController;
                popoverPresentationController.sourceView = sourceView;
                popoverPresentationController.sourceRect = sourceView.bounds;
                
                [self presentViewController:activityViewController animated:YES completion:nil];
            }]];
        }
        
        if (self.navigationController) {
            [alertController addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Open", @"Button label to open a show from the from the long-press menu") style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                ShowViewController *showViewController = [[ShowViewController alloc] initWithShow:show fromPushNotification:NO];
                [self.navigationController pushViewController:showViewController animated:YES];
            }]];
        }
        [alertController addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Cancel", @"Label of the button to close the show long-press menu") style:UIAlertActionStyleCancel handler:nil]];
    }
    else {
        return;
    }
    
    UIPopoverPresentationController *popoverPresentationController = alertController.popoverPresentationController;
    popoverPresentationController.sourceView = sourceView;
    
    NSValue *previewAnchorRect = [sourceView respondsToSelector:@selector(previewAnchorRect)] ? [(id<Previewing>)sourceView previewAnchorRect] : nil;
    popoverPresentationController.sourceRect = previewAnchorRect ? previewAnchorRect.CGRectValue : sourceView.bounds;
    [self presentViewController:alertController animated:YES completion:nil];
}

@end
