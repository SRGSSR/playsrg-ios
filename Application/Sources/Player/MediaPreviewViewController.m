//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "MediaPreviewViewController.h"

#import "ActivityItemSource.h"
#import "AnalyticsConstants.h"
#import "ApplicationConfiguration.h"
#import "ApplicationSettings.h"
#import "Banner.h"
#import "Download.h"
#import "GoogleCast.h"
#import "History.h"
#import "MediaPlayerViewController.h"
#import "NSDateFormatter+PlaySRG.h"
#import "PlayAppDelegate.h"
#import "PlayErrors.h"
#import "ShowViewController.h"
#import "SRGDataProvider+PlaySRG.h"
#import "SRGMedia+PlaySRG.h"
#import "SRGMediaComposition+PlaySRG.h"
#import "UIImageView+PlaySRG.h"
#import "UIStackView+PlaySRG.h"
#import "UIView+PlaySRG.h"
#import "UIViewController+PlaySRG.h"
#import "UIWindow+PlaySRG.h"
#import "WatchLater.h"

#import <Masonry/Masonry.h>
#import <SRGAnalytics_DataProvider/SRGAnalytics_DataProvider.h>
#import <SRGAppearance/SRGAppearance.h>
#import <SRGMediaPlayer/SRGMediaPlayer.h>

@interface MediaPreviewViewController ()

@property (nonatomic) SRGMedia *media;

@property (nonatomic) IBOutlet SRGLetterboxController *letterboxController;      // top object, strong
@property (nonatomic, weak) IBOutlet SRGLetterboxView *letterboxView;

@property (nonatomic, weak) IBOutlet UILabel *titleLabel;

@property (nonatomic, weak) IBOutlet UIStackView *mediaInfoStackView;
@property (nonatomic, weak) IBOutlet UILabel *showLabel;
@property (nonatomic, weak) IBOutlet UILabel *summaryLabel;

@property (nonatomic, weak) IBOutlet UIStackView *channelInfoStackView;
@property (nonatomic, weak) IBOutlet UILabel *programTimeLabel;
@property (nonatomic, weak) IBOutlet UILabel *channelLabel;

@property (nonatomic) BOOL shouldRestoreServicePlayback;
@property (nonatomic, copy) NSString *previousAudioSessionCategory;

@end

@implementation MediaPreviewViewController

#pragma mark Object lifecycle

- (instancetype)initWithMedia:(SRGMedia *)media
{
    if (self = [super init]) {
        self.media = media;
    }
    return self;
}

#pragma mark View lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    // Will restore audio playback iff a controller attached to the service was actually playing audio before (ignore
    // other running playback playback states, like stalled or seeking, since such cases are not really relevant and
    // cannot be restored anyway as is)
    SRGLetterboxController *serviceController = SRGLetterboxService.sharedService.controller;
    if (serviceController.media.mediaType == SRGMediaTypeAudio && serviceController.playbackState == SRGMediaPlayerPlaybackStatePlaying) {
        [serviceController pause];
        self.shouldRestoreServicePlayback = YES;
    }
    
    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(applicationDidBecomeActive:)
                                               name:UIApplicationDidBecomeActiveNotification
                                             object:nil];
    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(mediaMetadataDidChange:)
                                               name:SRGLetterboxMetadataDidChangeNotification
                                             object:self.letterboxController];
    
    self.letterboxController.contentURLOverridingBlock = ^(NSString *URN) {
        Download *download = [Download downloadForURN:URN];
        return download.localMediaFileURL;
    };
    ApplicationConfigurationApplyControllerSettings(self.letterboxController);
    
    [self.letterboxController playMedia:self.media atPosition:HistoryResumePlaybackPositionForMedia(self.media) withPreferredSettings:ApplicationSettingPlaybackSettings()];
    [self.letterboxView setUserInterfaceHidden:YES animated:NO togglable:NO];
    [self.letterboxView setTimelineAlwaysHidden:YES animated:NO];
    
    [self reloadData];
    [self updateFonts];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    if ([self play_isMovingToParentViewController]) {
        // Height set to twice the video height (with 16/9 ratio) for regular sizes. Only display the video for
        // compact layouts (currently iPhone Plus) since more readable
        CGFloat width = CGRectGetWidth(self.view.frame);
        CGFloat factor = (self.traitCollection.verticalSizeClass == UIUserInterfaceSizeClassCompact) ? 1.f : 2.f;
        self.preferredContentSize = CGSizeMake(width, factor * 9.f / 16.f * width);
        
        self.previousAudioSessionCategory = [AVAudioSession sharedInstance].category;
        [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback error:nil];
    }
    
    if (self.letterboxController.mediaComposition) {
        [self srg_trackPageView];
    }
}

- (void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
    
    if ([self play_isMovingFromParentViewController]) {
        // Restore playback on exit. Works well with cancelled peek, as well as with pop, without additional checks. Wait
        // a little bit since peek view dismissal occurs just before an action item has been selected. Moreover, having
        // a small delay sounds better.
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            if (self.shouldRestoreServicePlayback) {
                [[AVAudioSession sharedInstance] setCategory:self.previousAudioSessionCategory error:nil];
                [SRGLetterboxService.sharedService.controller play];
            }
        });
    }
}

#pragma mark Rotation

- (UIInterfaceOrientationMask)supportedInterfaceOrientations
{
    return [super supportedInterfaceOrientations] & UIViewController.play_supportedInterfaceOrientations;
}

#pragma mark Accessibility

- (void)updateForContentSizeCategory
{
    [super updateForContentSizeCategory];
    
    [self updateFonts];
}

#pragma mark Peek and pop

- (NSArray<id<UIPreviewActionItem>> *)previewActionItems
{
    NSMutableArray<id<UIPreviewActionItem>> *previewActionItems = [NSMutableArray array];
    
    if (WatchLaterCanStoreMediaMetadata(self.media)) {
        BOOL inWatchLaterList = WatchLaterContainsMediaMetadata(self.media);
        UIPreviewAction *watchLaterAction = [UIPreviewAction actionWithTitle:inWatchLaterList ? NSLocalizedString(@"Remove from \"Watch later\"", @"Button label to remove a media from the watch later list, from the media preview window") : NSLocalizedString(@"Add to \"Watch later\"", @"Button label to add a media to the watch later list, from the media preview window") style:inWatchLaterList ? UIPreviewActionStyleDestructive : UIPreviewActionStyleDefault handler:^(UIPreviewAction * _Nonnull action, UIViewController * _Nonnull previewViewController) {
            WatchLaterToggleMediaMetadata(self.media, ^(BOOL added, NSError * _Nullable error) {
                if (! error) {
                    AnalyticsTitle analyticsTitle = added ? AnalyticsTitleWatchLaterAdd : AnalyticsTitleWatchLaterRemove;
                    SRGAnalyticsHiddenEventLabels *labels = [[SRGAnalyticsHiddenEventLabels alloc] init];
                    labels.source = AnalyticsSourcePeekMenu;
                    labels.value = self.media.URN;
                    [SRGAnalyticsTracker.sharedTracker trackHiddenEventWithName:analyticsTitle labels:labels];
                    
                    [Banner showWatchLaterAdded:added forItemWithName:self.media.title inViewController:nil /* Not 'self' since dismissed */];
                }
            });
        }];
        [previewActionItems addObject:watchLaterAction];
    }
    
    BOOL downloadable = [Download canDownloadMedia:self.media];
    if (downloadable) {
        Download *download = [Download downloadForMedia:self.media];
        BOOL downloaded = (download != nil);
        UIPreviewAction *downloadAction = [UIPreviewAction actionWithTitle:downloaded ? NSLocalizedString(@"Remove from downloads", @"Button label to remove a download from the media preview window") : NSLocalizedString(@"Add to downloads", @"Button label to add a download from the media preview window") style:downloaded ? UIPreviewActionStyleDestructive : UIPreviewActionStyleDefault handler:^(UIPreviewAction * _Nonnull action, UIViewController * _Nonnull previewViewController) {
            if (downloaded) {
                [Download removeDownload:download];
            }
            else {
                [Download addDownloadForMedia:self.media];
            }
            
            // Use !downloaded since the status has been reversed
            AnalyticsTitle analyticsTitle = (! downloaded) ? AnalyticsTitleDownloadAdd : AnalyticsTitleDownloadRemove;
            SRGAnalyticsHiddenEventLabels *labels = [[SRGAnalyticsHiddenEventLabels alloc] init];
            labels.source = AnalyticsSourcePeekMenu;
            labels.value = self.media.URN;
            [SRGAnalyticsTracker.sharedTracker trackHiddenEventWithName:analyticsTitle labels:labels];
        }];
        [previewActionItems addObject:downloadAction];
    }
    
    NSURL *sharingURL = [ApplicationConfiguration.sharedApplicationConfiguration sharingURLForMediaMetadata:self.media atTime:kCMTimeZero];
    if (sharingURL) {
        UIPreviewAction *shareAction = [UIPreviewAction actionWithTitle:NSLocalizedString(@"Share", @"Button label of the sharing choice in the media preview window") style:UIPreviewActionStyleDefault handler:^(UIPreviewAction * _Nonnull action, UIViewController * _Nonnull previewViewController) {
            ActivityItemSource *activityItemSource = [[ActivityItemSource alloc] initWithMedia:self.media URL:sharingURL];
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
                labels.value = self.media.URN;
                labels.extraValue1 = AnalyticsTypeValueSharingContent;
                [SRGAnalyticsTracker.sharedTracker trackHiddenEventWithName:AnalyticsTitleSharingMedia labels:labels];
                
                SRGSubdivision *subdivision = [self.letterboxController.mediaComposition subdivisionWithURN:self.media.URN];
                if (subdivision) {
                    [[SRGDataProvider.currentDataProvider play_increaseSocialCountForActivityType:activityType subdivision:subdivision withCompletionBlock:^(SRGSocialCountOverview * _Nullable socialCountOverview, NSHTTPURLResponse * _Nullable HTTPResponse, NSError * _Nullable error) {
                        // Nothing
                    }] resume];
                }
                
                if ([activityType isEqualToString:UIActivityTypeCopyToPasteboard]) {
                    [Banner showWithStyle:BannerStyleInfo
                                  message:NSLocalizedString(@"The content has been copied to the clipboard.", @"Message displayed when some content (media, show, etc.) has been copied to the clipboard")
                                    image:nil
                                   sticky:NO
                         inViewController:nil /* Not 'self' since dismissed */];
                }
            };
            
            activityViewController.modalPresentationStyle = UIModalPresentationPopover;
            
            UIViewController *viewController = self.play_previewingContext.sourceView.nearestViewController;
            [viewController presentViewController:activityViewController animated:YES completion:nil];
        }];
        [previewActionItems addObject:shareAction];
    }
    
    if (! ApplicationConfiguration.sharedApplicationConfiguration.moreEpisodesHidden && self.media.show) {
        UIPreviewAction *showAction = [UIPreviewAction actionWithTitle:NSLocalizedString(@"More episodes", @"Button label to open the show episode page from the preview window") style:UIPreviewActionStyleDefault handler:^(UIPreviewAction * _Nonnull action, UIViewController * _Nonnull previewViewController) {
            ShowViewController *showViewController = [[ShowViewController alloc] initWithShow:self.media.show fromPushNotification:NO];
            
            UIViewController *viewController = self.play_previewingContext.sourceView.nearestViewController;
            UINavigationController *navigationController = viewController.navigationController;
            if (navigationController) {
                [navigationController pushViewController:showViewController animated:YES];
            }
            else {
                UIApplication *application = UIApplication.sharedApplication;
                PlayAppDelegate *appDelegate = (PlayAppDelegate *)application.delegate;
                [appDelegate.rootTabBarController pushViewController:showViewController animated:YES];
            }
        }];
        [previewActionItems addObject:showAction];
    }
    
    UIPreviewAction *openAction = [UIPreviewAction actionWithTitle:NSLocalizedString(@"Open", @"Button label to open a media from the start from the preview window") style:UIPreviewActionStyleDefault handler:^(UIPreviewAction * _Nonnull action, UIViewController * _Nonnull previewViewController) {
        self.shouldRestoreServicePlayback = NO;
        
        UIView *sourceView = self.play_previewingContext.sourceView;
        [sourceView.nearestViewController play_presentMediaPlayerFromLetterboxController:self.letterboxController withAirPlaySuggestions:NO fromPushNotification:NO animated:YES completion:nil];
    }];
    [previewActionItems addObject:openAction];
    
    return previewActionItems.copy;
}

#pragma mark Data

- (void)reloadData
{
    if (self.media.contentType == SRGContentTypeLivestream) {
        [self.mediaInfoStackView play_setHidden:YES];
        
        SRGChannel *channel = self.letterboxController.channel;
        if (channel) {
            [self.channelInfoStackView play_setHidden:NO];
            
            SRGProgram *currentProgram = channel.currentProgram;
            if (currentProgram) {
                self.titleLabel.text = currentProgram.title;
                
                self.channelLabel.font = [UIFont srg_mediumFontWithTextStyle:SRGAppearanceFontTextStyleSubtitle];
                self.channelLabel.text = channel.title;
                
                self.programTimeLabel.font = [UIFont srg_lightFontWithTextStyle:SRGAppearanceFontTextStyleBody];
                self.programTimeLabel.text = [NSString stringWithFormat:@"%@ - %@", [NSDateFormatter.play_timeFormatter stringFromDate:currentProgram.startDate], [NSDateFormatter.play_timeFormatter stringFromDate:currentProgram.endDate]];
            }
            else {
                self.titleLabel.text = channel.title;
                self.channelLabel.text = nil;
                self.programTimeLabel.text = nil;
            }
        }
        else {
            self.titleLabel.text = self.media.title;
            
            [self.channelInfoStackView play_setHidden:YES];
        }
    }
    else {
        self.titleLabel.text = self.media.title;
        self.showLabel.text = (self.media.show.title && ! [self.media.title containsString:self.media.show.title]) ? self.media.show.title : nil;
        
        [self.mediaInfoStackView play_setHidden:NO];
        [self.channelInfoStackView play_setHidden:YES];
        
        self.summaryLabel.text = self.media.play_fullSummary;
    }
}

#pragma mark UI

- (void)updateFonts
{
    self.titleLabel.font = [UIFont srg_mediumFontWithTextStyle:SRGAppearanceFontTextStyleTitle];
    self.showLabel.font = [UIFont srg_mediumFontWithTextStyle:SRGAppearanceFontTextStyleBody];
    self.summaryLabel.font = [UIFont srg_regularFontWithTextStyle:SRGAppearanceFontTextStyleBody];
    
    self.programTimeLabel.font = [UIFont srg_lightFontWithTextStyle:SRGAppearanceFontTextStyleBody];
    self.channelLabel.font = [UIFont srg_mediumFontWithTextStyle:SRGAppearanceFontTextStyleSubtitle];
}

#pragma mark SRGAnalyticsViewTracking protocol

- (BOOL)srg_isTrackedAutomatically
{
    // Tracking requires media composition information. The view event will be sent manually when appropriate
    return NO;
}

- (NSString *)srg_pageViewTitle
{
    // Use the full-length when available
    SRGMedia *media = self.letterboxController.fullLengthMedia ?: self.letterboxController.media;
    return media.title;
}

- (NSArray<NSString *> *)srg_pageViewLevels
{
    NSMutableArray<NSString *> *levels = [NSMutableArray array];
    
    // Use the full-length when available
    SRGMedia *media = self.letterboxController.fullLengthMedia ?: self.letterboxController.media;
    if (media.mediaType == SRGMediaTypeAudio) {
        [levels addObject:AnalyticsNameForPageType(AnalyticsPageTypeRadio)];
    }
    else {
        [levels addObject:AnalyticsNameForPageType(AnalyticsPageTypeTV)];
    }
    [levels addObject:@"preview"];
    
    NSString *showTitle = self.letterboxController.mediaComposition.show.title;
    if (showTitle) {
        [levels addObject:showTitle];
    }
    
    return levels.copy;
}

#pragma mark Notifications

- (void)mediaMetadataDidChange:(NSNotification *)notification
{
    [self reloadData];
    
    // Notify page view when the full-length changes.
    SRGMediaComposition *previousMediaComposition = notification.userInfo[SRGLetterboxPreviousMediaCompositionKey];
    SRGMediaComposition *mediaComposition = notification.userInfo[SRGLetterboxMediaCompositionKey];
    
    if ([self isViewVisible] && mediaComposition && ! [mediaComposition.fullLengthMedia isEqual:previousMediaComposition.fullLengthMedia]) {
        [self srg_trackPageView];
    }
}

- (void)applicationDidBecomeActive:(NSNotification *)notification
{
    // Automatically resumes playback since we have no controls
    [self.letterboxController togglePlayPause];
}

@end
